output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "ARN for the GitHub Actions pipeline to assume"
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.app.repository_url
  description = "The URL of the ECR repository for image tags"
}

output "ecs_cluster_name" {
  value       = aws_ecs_cluster.main.name
  description = "Name of the created ECS Cluster"
}

output "ecs_service_name" {
  value       = aws_ecs_service.main.name
  description = "Name of the running ECS Service"
}