resource "aws_ecr_repository" "absolute_repo" {
  name                 = "absolute-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "absolute-repo"
    Environment = var.environment
  }
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.absolute_repo.repository_url
}
