# OpenID Connect (OIDC) Provider for Keyless GitHub Actions Authentication

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a21d286dd77ed79d9af1380db314294d29f7"
  ]
}

# IAM Role assumed dynamically by GitHub Actions without static AWS keys
resource "aws_iam_role" "github_actions" {
  name        = "absolute-github-actions-${var.environment}"
  description = "IAM Role assumed by GitHub Actions via OIDC keyless federation"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # FIX: was $${var.github_repo} — escaped literal, any repo could assume this role!
            # Now correctly interpolates the actual repository value.
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })
}

# Scoped IAM policy — least-privilege for CI/CD deployment operations.
# Replaces the previous AdministratorAccess (over-privileged).
resource "aws_iam_role_policy" "github_actions_deploy" {
  name = "absolute-github-actions-deploy-policy-${var.environment}"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECR — push images and manage the repository
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:CreateRepository",
          "ecr:DescribeRepositories",
          "ecr:ListTagsForResource",
          "ecr:TagResource"
        ]
        Resource = "arn:aws:ecr:*:*:repository/absolute-*"
      },
      # S3 — Terraform remote state backend
      {
        Sid    = "TerraformStateS3"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration",
          "s3:CreateBucket",
          "s3:GetBucketLocation",
          "s3:ListBucketVersions",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging"
        ]
        Resource = [
          "arn:aws:s3:::absolute-tfstate-*",
          "arn:aws:s3:::absolute-tfstate-*/*"
        ]
      },
      # DynamoDB — Terraform state locking
      {
        Sid    = "TerraformStateLock"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable",
          "dynamodb:CreateTable",
          "dynamodb:ListTagsOfResource",
          "dynamodb:TagResource"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/absolute-tflocks-*"
      },
      # EC2 / ASG — launch templates, auto scaling, security groups
      {
        Sid    = "EC2ASG"
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeImages",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateLaunchTemplateVersion",
          "ec2:DeleteLaunchTemplate",
          "ec2:ModifyLaunchTemplate",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "AutoScaling"
        Effect = "Allow"
        Action = [
          "autoscaling:CreateAutoScalingGroup",
          "autoscaling:UpdateAutoScalingGroup",
          "autoscaling:DeleteAutoScalingGroup",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:StartInstanceRefresh",
          "autoscaling:DescribeInstanceRefreshes",
          "autoscaling:CreateOrUpdateTags",
          "autoscaling:DeleteTags",
          "autoscaling:DescribeTags"
        ]
        Resource = "*"
      },
      # ELB — Application Load Balancer & Target Groups
      {
        Sid    = "ELB"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags",
          "elasticloadbalancing:DescribeTags"
        ]
        Resource = "*"
      },
      # RDS — PostgreSQL database
      {
        Sid    = "RDS"
        Effect = "Allow"
        Action = [
          "rds:CreateDBInstance",
          "rds:DeleteDBInstance",
          "rds:DescribeDBInstances",
          "rds:ModifyDBInstance",
          "rds:CreateDBSubnetGroup",
          "rds:DeleteDBSubnetGroup",
          "rds:DescribeDBSubnetGroups",
          "rds:AddTagsToResource",
          "rds:RemoveTagsFromResource",
          "rds:ListTagsForResource"
        ]
        Resource = "*"
      },
      # SSM — read/write application secrets
      {
        Sid    = "SSMParameters"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:PutParameter",
          "ssm:DeleteParameter",
          "ssm:DescribeParameters",
          "ssm:AddTagsToResource",
          "ssm:ListTagsForResource"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/absolute/*"
      },
      # IAM — manage EC2 instance profile and OIDC provider (self-managed)
      {
        Sid    = "IAMInstanceProfile"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:PassRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:CreateRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:ListInstanceProfilesForRole",
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider",
          "iam:UpdateOpenIDConnectProviderThumbprint",
          "iam:TagOpenIDConnectProvider",
          "iam:ListOpenIDConnectProviders",
          "iam:TagRole",
          "iam:UntagRole"
        ]
        Resource = "*"
      }
    ]
  })
}
