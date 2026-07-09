# ==========================================
# STAGE 1: Builder
# ==========================================
FROM python:3.12-slim AS builder

WORKDIR /app

# Install build dependencies if needed (curl kept for completeness)
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install boto3 aws-xray-sdk

COPY app/ .

# ==========================================
# STAGE 2: Final Runtime
# ==========================================
FROM python:3.12-slim

WORKDIR /app

# Install curl in the final stage so the health check command works
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy installed dependencies and application code from the builder stage
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /app /app

EXPOSE 80

# Health check using native curl
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:80/health || exit 1

# Run your python application as a single foreground process
CMD ["python", "app.py"]