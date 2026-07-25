resource "aws_db_subnet_group" "rds" {
  name       = "absolute-rds-subnet-group-${var.environment}"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name        = "absolute-rds-subnet-group"
    Environment = var.environment
  }
}

resource "aws_security_group" "rds" {
  name        = "absolute-rds-sg-${var.environment}"
  description = "Security group for Absolute PostgreSQL RDS"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "Allow PostgreSQL from BEAM nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.beam_cluster_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "absolute-rds-sg"
    Environment = var.environment
  }
}

resource "aws_db_instance" "postgres" {
  identifier        = "absolute-db-${var.environment}"
  engine            = "postgres"
  engine_version    = "17"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp3"
  db_name           = "absolute_prod"
  username          = "postgres"
  # Reference the canonical random_password from ssm.tf — both RDS and SSM use the SAME password
  password                     = random_password.postgres_password.result
  db_subnet_group_name         = aws_db_subnet_group.rds.name
  vpc_security_group_ids       = [aws_security_group.rds.id]
  skip_final_snapshot          = true
  publicly_accessible          = false
  storage_encrypted            = true
  performance_insights_enabled = true
  
  backup_retention_period         = 7
  backup_window                   = "03:00-04:00"
  maintenance_window              = "sun:04:00-sun:05:00"
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  deletion_protection             = false

  lifecycle {
    ignore_changes  = [password]
  }

  tags = {
    Name        = "absolute-postgres"
    Environment = var.environment
  }
}

# Store the RDS endpoint in SSM so EC2 instances can resolve the DB host at runtime
# NOTE: The postgres_password SSM parameter is managed in ssm.tf to avoid duplication
resource "aws_ssm_parameter" "db_host" {
  name      = "/absolute/${var.environment}/postgres_host"
  type      = "String"
  value     = aws_db_instance.postgres.address
  overwrite = true

  tags = {
    Environment = var.environment
  }
}
