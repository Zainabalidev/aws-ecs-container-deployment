# ==============================================================================
# 1. GITHUB ACTIONS IDENTITY & IAM MANAGEMENT
# ==============================================================================
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        StringLike   = { "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*" }
      }
    }]
  })
}

resource "aws_iam_policy" "github_actions_policy" {
  name        = "GitHubActions-ECS-IAM-Management"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowTaskExecutionRoleManagement"
        Effect = "Allow"
        Action = ["iam:CreateRole", "iam:GetRole", "iam:PutRolePolicy", "iam:DeleteRole", "iam:AttachRolePolicy", "iam:DetachRolePolicy"]
        Resource = "arn:aws:iam::*:role/${var.project_name}-task-exec-${var.environment}"
      },
      {
        Sid    = "AllowInfrastructureManagement"
        Effect = "Allow"
        Action = ["ecs:*", "ecr:*", "logs:*", "vpc:*", "ec2:*"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_attach" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_policy.arn
}

# ==============================================================================
# 2. NETWORKING
# ==============================================================================
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "gw" { vpc_id = aws_vpc.main.id }

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" { 
  subnet_id = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id 
  }

resource "aws_route_table_association" "b" { 
  subnet_id = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id 
 }

# ==============================================================================
# 3. CONTAINER REGISTRY & LOGGING
# ==============================================================================
resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-${var.environment}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}-${var.environment}"
  retention_in_days = 7
}

# ==============================================================================
# 4. IAM ROLES (EXECUTION & TASK ROLE)
# ==============================================================================
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-task-exec-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_standard" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# NEW: Task Role for Application permissions (CloudWatch)
resource "aws_iam_role" "ecs_task_app_role" {
  name = "${var.project_name}-task-app-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" } }]
  })
}

resource "aws_iam_policy" "ecs_cw_metrics" {
  name = "${var.project_name}-cw-metrics-${var.environment}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["cloudwatch:PutMetricData"], Resource = "*" }]
  })
}

resource "aws_iam_role_policy_attachment" "app_metrics_attach" {
  role       = aws_iam_role.ecs_task_app_role.name
  policy_arn = aws_iam_policy.ecs_cw_metrics.arn
}

# ==============================================================================
# 5. ECS CLUSTER, SERVICE, AND SECURITY GROUPS
# ==============================================================================
resource "aws_ecs_cluster" "main" { name = "${var.project_name}-cluster-${var.environment}" }

resource "aws_security_group" "ecs_tasks" {
  name   = "${var.project_name}-tasks-sg"
  vpc_id = aws_vpc.main.id
  ingress { 
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
    }
  egress { 
    from_port = 0
    to_port = 0 
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"] 
    }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_app_role.arn # Attached Task Role

  container_definitions = jsonencode([{
    name      = var.project_name
    image     = "${aws_ecr_repository.app.repository_url}:latest"
    essential = true
    portMappings = [
      { 
      containerPort = 80
      hostPort = 80 
     }
     ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "main" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }
  lifecycle { ignore_changes = [task_definition] }
}