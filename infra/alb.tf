# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "absolute-alb-sg-${var.environment}"
  description = "Security group for Absolute Application Load Balancer"
  vpc_id      = data.aws_vpc.default.id

  # Inbound HTTP
  ingress {
    description = "HTTP Public Access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound HTTPS (For later if SSL is added)
  ingress {
    description = "HTTPS Public Access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound All Traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "absolute-alb-sg"
    Environment = var.environment
  }
}

# Application Load Balancer
resource "aws_lb" "absolute_alb" {
  name               = "absolute-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids

  enable_deletion_protection = false
  drop_invalid_header_fields = true

  tags = {
    Name        = "absolute-alb"
    Environment = var.environment
  }
}

# Target Group
resource "aws_lb_target_group" "absolute_tg" {
  name     = "absolute-tg-${var.environment}"
  port     = 4000
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/api/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = {
    Name        = "absolute-tg"
    Environment = var.environment
  }
}

# HTTP Listener
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.absolute_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.absolute_tg.arn
  }
}

output "alb_dns_name" {
  description = "The DNS name of the ALB"
  value       = aws_lb.absolute_alb.dns_name
}
