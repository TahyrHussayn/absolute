variable "aws_region" {
  description = "AWS Region to deploy infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "instance_type" {
  description = "EC2 Instance type (t3.micro is 12-month free tier eligible)"
  type        = string
  default     = "t3.micro"
}

variable "node_count" {
  description = "Number of EC2 instances to deploy for the BEAM cluster"
  type        = number
  default     = 2
}

variable "key_name" {
  description = "Optional AWS SSH Key Pair name for SSH access to EC2 nodes (leave empty to disable)"
  type        = string
  default     = ""
}

variable "repo_url" {
  description = "Git repository URL for Absolute application"
  type        = string
  default     = "https://github.com/tahyrhussayn/absolute.git"
}

variable "github_repo" {
  description = "GitHub Repository string (owner/repo) for OIDC identity federation"
  type        = string
  default     = "TahyrHussayn/absolute"
}

variable "image_tag" {
  description = "Docker image tag to deploy to the ASG"
  type        = string
  default     = "latest"
}

variable "alert_email" {
  description = "Email address for CloudWatch Alarm notifications"
  type        = string
  default     = "admin@example.com"
}
