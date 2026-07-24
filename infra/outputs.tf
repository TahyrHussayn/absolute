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
