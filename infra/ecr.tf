resource "aws_ecr_repository" "absolute_repo" {
  name                 = "absolute-${var.environment}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "absolute-repo"
    Environment = var.environment
  }
}

resource "aws_ecr_lifecycle_policy" "absolute_repo_lifecycle" {
  repository = aws_ecr_repository.absolute_repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
