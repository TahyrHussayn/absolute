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
  description = "Optional AWS SSH Key Pair name for SSH access"
  type        = string
  default     = ""
}

variable "beam_cookie" {
  description = "Shared Erlang Cookie for BEAM node cluster authentication"
  type        = string
  default     = "absolute_secret_beam_cookie_2026"
  sensitive   = true
}

variable "repo_url" {
  description = "Git repository URL for Absolute application"
  type        = string
  default     = "https://github.com/tahyrhussayn/absolute.git"
}

variable "github_repo" {
  description = "GitHub Repository string (owner/repo) for OIDC identity federation"
  type        = string
  default     = "tahyrhussayn/absolute"
}
