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

resource "random_password" "db_password" {
  length  = 32
  special = false
}

resource "aws_db_instance" "postgres" {
  identifier                   = "absolute-db-${var.environment}"
  engine                       = "postgres"
  engine_version               = "16"
  instance_class               = "db.t3.micro"
  allocated_storage            = 20
  storage_type                 = "gp3"
  db_name                      = "absolute_prod"
  username                     = "postgres"
  password                     = random_password.db_password.result
  db_subnet_group_name         = aws_db_subnet_group.rds.name
  vpc_security_group_ids       = [aws_security_group.rds.id]
  skip_final_snapshot          = true
  publicly_accessible          = false
  storage_encrypted            = true
  performance_insights_enabled = true

  tags = {
    Name        = "absolute-postgres"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "db_password" {
  name      = "/absolute/${var.environment}/postgres_password"
  type      = "SecureString"
  value     = random_password.db_password.result
  overwrite = true
}

resource "aws_ssm_parameter" "db_host" {
  name      = "/absolute/${var.environment}/postgres_host"
  type      = "String"
  value     = aws_db_instance.postgres.address
  overwrite = true
}
