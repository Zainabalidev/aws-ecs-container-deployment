import json
import logging
import os
import time
from flask import Flask, jsonify, request
import boto3
from datetime import datetime

# Configure structured logging for CloudWatch
class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "level": record.levelname,
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno,
            "environment": os.getenv("ENVIRONMENT", "development"),
            "service": os.getenv("SERVICE_NAME", "my-web-app")
        }
        if hasattr(record, 'extra'):
            log_entry.update(record.extra)
        return json.dumps(log_entry)

# Configure logging
logger = logging.getLogger()
logger.setLevel(os.getenv("LOG_LEVEL", "INFO"))

# Remove existing handlers
for handler in logger.handlers[:]:
    logger.removeHandler(handler)

# Add JSON handler for CloudWatch
json_handler = logging.StreamHandler()
json_handler.setFormatter(JSONFormatter())
logger.addHandler(json_handler)

app = Flask(__name__)

# Custom metrics for CloudWatch
cloudwatch = boto3.client('cloudwatch', region_name=os.getenv("AWS_REGION", "us-east-1"))

def send_custom_metric(metric_name, value, unit="Count"):
    try:
        cloudwatch.put_metric_data(
            Namespace='Application/Custom',
            MetricData=[
                {
                    'MetricName': metric_name,
                    'Value': value,
                    'Unit': unit,
                    'Dimensions': [
                        {
                            'Name': 'Environment',
                            'Value': os.getenv("ENVIRONMENT", "development")
                        },
                        {
                            'Name': 'Service',
                            'Value': os.getenv("SERVICE_NAME", "my-web-app")
                        }
                    ]
                }
            ]
        )
        logger.info(f"Sent custom metric: {metric_name}={value}")
    except Exception as e:
        logger.error(f"Failed to send custom metric: {str(e)}")

@app.route('/')
def hello():
    start_time = time.time()
    
    try:
        # Log request
        logger.info("Handling root request", extra={
            "extra": {
                "ip": request.remote_addr,
                "user_agent": request.headers.get('User-Agent')
            }
        })
        
        response = {
            "message": "Hello from ECS Fargate!",
            "environment": os.getenv("ENVIRONMENT", "development"),
            "timestamp": datetime.utcnow().isoformat(),
            "version": os.getenv("APP_VERSION", "1.0.0")
        }
        
        # Send custom metric
        send_custom_metric("RootRequests", 1)
        
        # Calculate response time
        response_time = (time.time() - start_time) * 1000
        send_custom_metric("ResponseTime", response_time, "Milliseconds")
        
        logger.info("Request completed successfully", extra={
            "extra": {
                "response_time_ms": response_time,
                "status": 200
            }
        })
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Error in root endpoint: {str(e)}", extra={
            "extra": {
                "error_type": type(e).__name__
            }
        })
        send_custom_metric("Errors", 1)
        return jsonify({"error": "Internal server error"}), 500

@app.route('/health')
def health():
    try:
        # Check database connection or other dependencies here
        health_status = {
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat(),
            "uptime": time.time() - app.start_time if hasattr(app, 'start_time') else 0
        }
        logger.info("Health check performed", extra={
            "extra": health_status
        })
        return jsonify(health_status), 200
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return jsonify({"status": "unhealthy", "error": str(e)}), 500

@app.route('/metrics')
def metrics():
    """Custom metrics endpoint for CloudWatch"""
    try:
        # Send custom metrics
        send_custom_metric("MetricsAccessed", 1)
        
        return jsonify({
            "status": "ok",
            "message": "Custom metrics being sent to CloudWatch"
        }), 200
    except Exception as e:
        logger.error(f"Metrics endpoint error: {str(e)}")
        return jsonify({"error": str(e)}), 500

# Error handlers
@app.errorhandler(404)
def not_found(error):
    logger.warning("404 Not Found", extra={
        "extra": {
            "path": request.path,
            "method": request.method
        }
    })
    return jsonify({"error": "Not found"}), 404

@app.errorhandler(500)
def internal_error(error):
    logger.error("500 Internal Server Error", extra={
        "extra": {
            "path": request.path,
            "method": request.method
        }
    })
    send_custom_metric("ServerErrors", 1)
    return jsonify({"error": "Internal server error"}), 500

# Initialize app start time
app.start_time = time.time()

if __name__ == '__main__':
    logger.info(f"Starting application in {os.getenv('ENVIRONMENT', 'development')} mode")
    app.run(host='0.0.0.0', port=80)