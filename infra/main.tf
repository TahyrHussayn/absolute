terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Lookup default VPC & Subnets for easy zero-friction deployment
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1f"]
  }
}

# Dynamically query latest Ubuntu 24.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group: HTTP, HTTPS, SSH, and internal BEAM interconnect
resource "aws_security_group" "beam_cluster_sg" {
  name        = "absolute-beam-cluster-sg-${var.environment}"
  description = "Security group for Absolute Elixir/BEAM cluster nodes"
  vpc_id      = data.aws_vpc.default.id

  # Inbound HTTP from ALB (Port 4000 for the app)
  ingress {
    description     = "HTTP from ALB"
    from_port       = 4000
    to_port         = 4000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }


  # Inbound Erlang Port Mapper Daemon (EPMD) - Internal SG only
  ingress {
    description = "Erlang EPMD Interconnect"
    from_port   = 4369
    to_port     = 4369
    protocol    = "tcp"
    self        = true
  }

  # Inbound BEAM Node Distribution Range - Internal SG only
  ingress {
    description = "BEAM Distributed Cluster Interconnect"
    from_port   = 9000
    to_port     = 9005
    protocol    = "tcp"
    self        = true
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
    Name        = "absolute-beam-cluster-sg"
    Environment = var.environment
  }
}

# IAM Role & Profile for EC2 instances to fetch SSM parameters securely
resource "aws_iam_role" "ec2_ssm_role" {
  name = "absolute-ec2-ssm-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ec2_ssm_policy" {
  name = "absolute-ec2-ssm-policy-${var.environment}"
  role = aws_iam_role.ec2_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParameterHistory"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/absolute/${var.environment}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach AWS Managed SSM Instance Core policy to allow SSM session manager & remote management
resource "aws_iam_role_policy_attachment" "ec2_ssm_managed_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "absolute-ec2-instance-profile-${var.environment}"
  role = aws_iam_role.ec2_ssm_role.name
}


