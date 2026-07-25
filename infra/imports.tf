# Terraform 1.5+ Automatic Resource Adoption & Import Declarations
#
# NOTE: All import blocks have been intentionally removed.
# The AWS resources (S3 bucket, DynamoDB table, IAM roles, security groups)
# were fully destroyed in a previous teardown. On the next `terraform apply`
# (or `./scripts/bootstrap.sh`), Terraform will create all resources fresh.
#
# If you ever need to adopt existing resources into Terraform state,
# re-add import blocks here using:
#
#   import {
#     to = aws_s3_bucket.tf_state
#     id = "absolute-tfstate-production"
#   }
