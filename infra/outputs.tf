# All Terraform outputs are consolidated here.
# Do NOT define outputs in individual resource files (alb.tf, ecr.tf, etc.)

output "alb_dns_name" {
  description = "The public DNS name of the Application Load Balancer"
  value       = aws_lb.absolute_alb.dns_name
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository for pushing Docker images"
  value       = aws_ecr_repository.absolute_repo.repository_url
}

output "current_image_tag" {
  description = "The Docker image tag currently deployed by Terraform"
  value       = var.image_tag
}

output "github_oidc_role_arn" {
  description = "IAM Role ARN assumed by GitHub Actions via OIDC keyless authentication"
  value       = aws_iam_role.github_actions.arn
}

output "ssm_parameter_prefix" {
  description = "Prefix for AWS SSM Parameter Store encrypted secrets"
  value       = "/absolute/${var.environment}"
}

output "rds_endpoint" {
  description = "The connection endpoint for the RDS PostgreSQL instance"
  value       = aws_db_instance.postgres.address
}
