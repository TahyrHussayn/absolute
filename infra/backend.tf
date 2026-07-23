# Terraform Remote Backend & State Locking Resources (S3 + DynamoDB)
# Run `terraform apply` once to provision the S3 bucket & DynamoDB table for remote state storage.

resource "aws_s3_bucket" "tf_state" {
  bucket        = "absolute-tfstate-${var.environment}"
  force_destroy = false

  tags = {
    Name        = "absolute-tfstate"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# DynamoDB Table for Distributed State Locking (prevents concurrent deployment race conditions)
resource "aws_dynamodb_table" "tf_locks" {
  name         = "absolute-tflocks-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "absolute-tflocks"
    Environment = var.environment
  }
}
