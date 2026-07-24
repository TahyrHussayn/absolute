# Random Password & Secret Key Base Generators
resource "random_password" "postgres_password" {
  length  = 32
  special = false
}

resource "random_password" "secret_key_base" {
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
  description = "Shared Erlang cluster cookie"
  type        = "SecureString"
  value       = var.beam_cookie
  overwrite   = true

  tags = {
    Environment = var.environment
  }
}
