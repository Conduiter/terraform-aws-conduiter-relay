terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# CloudWatch Log Group
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "relay" {
  name              = "/conduiter/relay/${var.relay_name}"
  retention_in_days = 30

  tags = {
    Name        = "conduiter-relay-${var.relay_name}"
    Environment = var.relay_name
    Service     = "relay"
  }
}

# -----------------------------------------------------------------------------
# Secrets Manager - Relay Keypair
# -----------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "relay_keypair" {
  name                    = "conduiter/relay/${var.relay_name}/keypair"
  description             = "Conduiter relay keypair for ${var.relay_name}"
  recovery_window_in_days = 7

  tags = {
    Name        = "conduiter-relay-${var.relay_name}-keypair"
    Environment = var.relay_name
    Service     = "relay"
  }
}

resource "aws_secretsmanager_secret_version" "relay_keypair" {
  secret_id     = aws_secretsmanager_secret.relay_keypair.id
  secret_string = jsonencode({})

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# -----------------------------------------------------------------------------
# IAM - Task Execution Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "task_execution" {
  name = "conduiter-relay-${var.relay_name}-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "conduiter-relay-${var.relay_name}-task-execution"
    Environment = var.relay_name
    Service     = "relay"
  }
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "task_execution_secrets" {
  name = "secrets-access"
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.relay_keypair.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.relay.arn}:*"
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# IAM - Task Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "task" {
  name = "conduiter-relay-${var.relay_name}-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "conduiter-relay-${var.relay_name}-task"
    Environment = var.relay_name
    Service     = "relay"
  }
}

resource "aws_iam_role_policy" "task_secrets" {
  name = "secrets-access"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.relay_keypair.arn
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "relay_alb" {
  name        = "conduiter-relay-${var.relay_name}-alb"
  description = "Security group for Conduiter relay ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from allowed CIDRs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "conduiter-relay-${var.relay_name}-alb"
    Environment = var.relay_name
    Service     = "relay"
  }
}

resource "aws_security_group" "relay_task" {
  name        = "conduiter-relay-${var.relay_name}-task"
  description = "Security group for Conduiter relay ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Traffic from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.relay_alb.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "conduiter-relay-${var.relay_name}-task"
    Environment = var.relay_name
    Service     = "relay"
  }
}

# -----------------------------------------------------------------------------
# Application Load Balancer
# -----------------------------------------------------------------------------

resource "aws_lb" "relay" {
  name               = "conduiter-relay-${var.relay_name}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.relay_alb.id]
  subnets            = var.subnet_ids

  tags = {
    Name        = "conduiter-relay-${var.relay_name}"
    Environment = var.relay_name
    Service     = "relay"
  }
}

resource "aws_lb_target_group" "relay" {
  name        = "conduiter-relay-${var.relay_name}"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    path                = "/health"
    matcher             = "200"
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 300
    enabled         = true
  }

  tags = {
    Name        = "conduiter-relay-${var.relay_name}"
    Environment = var.relay_name
    Service     = "relay"
  }
}

resource "aws_lb_listener" "relay_https" {
  load_balancer_arn = aws_lb.relay.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.relay.arn
  }

  tags = {
    Name        = "conduiter-relay-${var.relay_name}-https"
    Environment = var.relay_name
    Service     = "relay"
  }
}

# -----------------------------------------------------------------------------
# ECS Cluster
# -----------------------------------------------------------------------------

resource "aws_ecs_cluster" "relay" {
  name = "conduiter-relay-${var.relay_name}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "conduiter-relay-${var.relay_name}"
    Environment = var.relay_name
    Service     = "relay"
  }
}

# -----------------------------------------------------------------------------
# ECS Task Definition
# -----------------------------------------------------------------------------

resource "aws_ecs_task_definition" "relay" {
  family                   = "conduiter-relay-${var.relay_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "relay"
      image     = "public.ecr.aws/conduiter/relay:${var.image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "CONDUITER_API_ENDPOINT"
          value = var.api_endpoint
        },
        {
          name  = "CONDUITER_RELAY_NAME"
          value = var.relay_name
        },
        {
          name  = "CONDUITER_MAX_DAEMONS"
          value = tostring(var.relay_max_daemons_per_instance)
        }
      ]

      secrets = [
        {
          name      = "CONDUITER_ORG_TOKEN"
          valueFrom = "${aws_secretsmanager_secret.relay_keypair.arn}:org_token::"
        },
        {
          name      = "CONDUITER_RELAY_PRIVATE_KEY"
          valueFrom = "${aws_secretsmanager_secret.relay_keypair.arn}:private_key::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.relay.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "relay"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget -qO- http://localhost:8080/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name        = "conduiter-relay-${var.relay_name}"
    Environment = var.relay_name
    Service     = "relay"
  }
}

# -----------------------------------------------------------------------------
# ECS Service
# -----------------------------------------------------------------------------

resource "aws_ecs_service" "relay" {
  name            = "conduiter-relay-${var.relay_name}"
  cluster         = aws_ecs_cluster.relay.id
  task_definition = aws_ecs_task_definition.relay.arn
  desired_count   = var.relay_min_instances
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.relay_task.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.relay.arn
    container_name   = "relay"
    container_port   = 8080
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = {
    Name        = "conduiter-relay-${var.relay_name}"
    Environment = var.relay_name
    Service     = "relay"
  }
}

# -----------------------------------------------------------------------------
# Auto Scaling
# -----------------------------------------------------------------------------

resource "aws_appautoscaling_target" "relay" {
  max_capacity       = var.relay_max_instances
  min_capacity       = var.relay_min_instances
  resource_id        = "service/${aws_ecs_cluster.relay.name}/${aws_ecs_service.relay.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "relay_memory" {
  name               = "conduiter-relay-${var.relay_name}-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.relay.resource_id
  scalable_dimension = aws_appautoscaling_target.relay.scalable_dimension
  service_namespace  = aws_appautoscaling_target.relay.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = 70
    scale_in_cooldown  = 600
    scale_out_cooldown = 60
  }
}
