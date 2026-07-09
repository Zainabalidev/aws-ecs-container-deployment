output "account_id" {
  description = "AWS account ID (auto-detected)"
  value       = data.aws_caller_identity.current.account_id
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.app.repository_url
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.app.dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.app.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.app.name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group"
  value       = aws_cloudwatch_log_group.app.name
}

output "application_url" {
  description = "Application URL"
  value       = "http://${aws_lb.app.dns_name}"
}

output "ecs_role_arn" {
  description = "The ARN of the IAM role for GitHub Actions or ECS execution"
  value       = aws_iam_role.ecs_task_execution.arn
}