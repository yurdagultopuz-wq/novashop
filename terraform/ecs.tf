# NovaShop — Amazon ECS Fargate ve ALB Modülü
# Serverless Container Orchestration with CloudWatch Container Insights

# 1. CloudWatch Log Grubu
resource "aws_cloudwatch_log_group" "ecs_ui" {
  name              = "/ecs/novashop-ui"
  retention_in_days = 7

  tags = {
    Name = "novashop-ecs-ui-logs"
  }
}

# 2. ECS Kümesi (Container Insights Aktif)
resource "aws_ecs_cluster" "main" {
  name = "novashop-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "novashop-ecs-cluster"
  }
}

# 3. ECS Task Execution IAM Rolü
resource "aws_iam_role" "ecs_execution_role" {
  name = "novashop-ecs-execution-role"

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
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 4. ALB Güvenlik Grubu
resource "aws_security_group" "alb_sg" {
  name        = "novashop-alb-sg"
  description = "Allow HTTP and HTTPS traffic to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP Public Access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS Public Access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "novashop-alb-sg"
  }
}

# 5. ECS Servis Güvenlik Grubu (Yalnızca ALB'den gelen 8080 portuna izin verir)
resource "aws_security_group" "ecs_service_sg" {
  name        = "novashop-ecs-service-sg"
  description = "Allow inbound traffic strictly from ALB to ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Traffic from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "novashop-ecs-service-sg"
  }
}

# 6. Application Load Balancer (ALB)
resource "aws_lb" "main" {
  name               = "novashop-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "novashop-alb"
  }
}

# 7. ALB Target Group (Spring Boot Actuator Sağlık Kontrollü)
resource "aws_lb_target_group" "ui" {
  name        = "novashop-ecs-ui-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/actuator/health"
    port                = "8080"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "novashop-ecs-ui-tg"
  }
}

# 8. ALB HTTP Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ui.arn
  }
}

# 9. ECS Fargate Görev Tanımı (Task Definition)
resource "aws_ecs_task_definition" "ui" {
  family                   = "novashop-ui"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"  # 0.5 vCPU
  memory                   = "1024" # 1024 MiB
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "ui"
      image     = "public.ecr.aws/aws-containers/retail-store-sample-ui:1.6.2"
      essential = true
      user      = "appuser"
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "SPRING_PROFILES_ACTIVE", value = "prod" },
        { name = "JAVA_TOOL_OPTIONS", value = "-XX:MaxRAMPercentage=75.0" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_ui.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ui"
        }
      }
    }
  ])

  tags = {
    Name = "novashop-ecs-ui-task"
  }
}

# 10. ECS Fargate Servisi (Çoklu AZ, Private Subnet, Rolling Update)
resource "aws_ecs_service" "ui" {
  name            = "novashop-ui-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.ui.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = aws_subnet.public[*].id # Lab kolaylığı için public IP (veya NAT Gateway ile private)
    security_groups  = [aws_security_group.ecs_service_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ui.arn
    container_name   = "ui"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Name = "novashop-ui-service"
  }
}
