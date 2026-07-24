# Terraform 1.5+ Automatic Resource Adoption & Import Declarations
# Ensures CI/CD terraform apply seamlessly adopts existing AWS infrastructure

import {
  to = aws_s3_bucket.tf_state
  id = "absolute-tfstate-production"
}

import {
  to = aws_dynamodb_table.tf_locks
  id = "absolute-tflocks-production"
}

import {
  to = aws_iam_role.ec2_ssm_role
  id = "absolute-ec2-ssm-role-production"
}

import {
  to = aws_iam_role.github_actions
  id = "absolute-github-actions-production"
}

import {
  to = aws_security_group.beam_cluster_sg
  id = "sg-02ee0b7f4307b5477"
}

import {
  to = aws_iam_instance_profile.ec2_profile
  id = "absolute-ec2-instance-profile-production"
}
