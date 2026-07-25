# Random secret generators
# NOTE: random_password.postgres_password is the SINGLE canonical source of the DB password.
# Both ssm.tf (for storing in SSM) and rds.tf (for the RDS instance) reference this same resource.
resource "random_password" "postgres_password" {
  length  = 32
  special = false
}

resource "random_password" "secret_key_base" {
  length  = 64
  special = false
}

# Auto-generated Erlang distribution cookie for BEAM cluster authentication.
# All ASG nodes fetch this from SSM at startup — no manual secret needed.
resource "random_password" "beam_cookie" {
  length  = 64
  special = false
}

# AWS SSM Parameter Store: Encrypted Application Secrets
resource "aws_ssm_parameter" "postgres_password" {
  name        = "/absolute/${var.environment}/postgres_password"
  description = "Production PostgreSQL master password"
  type        = "SecureString"
  value       = random_password.postgres_password.result
  overwrite   = true

  tags = {
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "secret_key_base" {
  name        = "/absolute/${var.environment}/secret_key_base"
  description = "Production Phoenix secret key base"
  type        = "SecureString"
  value       = random_password.secret_key_base.result
  overwrite   = true

  tags = {
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "beam_cookie" {
  name        = "/absolute/${var.environment}/beam_cookie"
  description = "Shared Erlang cluster cookie — auto-generated, never needs manual rotation"
  type        = "SecureString"
  value       = random_password.beam_cookie.result
  overwrite   = true

  tags = {
    Environment = var.environment
  }
}
