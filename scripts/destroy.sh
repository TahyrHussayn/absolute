#!/usr/bin/env bash
# ==============================================================================
# Absolute — Total AWS Resource Teardown & Destruction Script (Zero Cost)
# ==============================================================================
# This script BRUTALLY destroys every single AWS resource created by Terraform,
# including EC2 instances, Security Groups, IAM Roles, SSM Parameters, OIDC providers,
# S3 state buckets, and DynamoDB lock tables to ensure ZERO ongoing AWS charges.
#
# Usage:
#   make destroy
#   # OR
#   mix destroy
# ==============================================================================

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

BUCKET_NAME="absolute-tfstate-production"
ECR_REPO_NAME="absolute-production"
AWS_REGION="us-east-1"

echo -e "${BOLD}${RED}=====================================================${NC}"
echo -e "${BOLD}${RED} 💣 Absolute — Total AWS Resource Teardown         ${NC}"
echo -e "${BOLD}${RED}=====================================================${NC}"

# 1. Prerequisite Checks
command -v aws >/dev/null 2>&1 || { echo -e "${RED}❌ AWS CLI is required but not installed.${NC}"; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo -e "${RED}❌ Terraform CLI is required but not installed.${NC}"; exit 1; }

# 2. Verify AWS Authentication
echo -e "\n${YELLOW}🔍 Verifying AWS authentication...${NC}"
CALLER_IDENTITY=$(aws sts get-caller-identity --output json 2>/dev/null) || {
  echo -e "${RED}❌ Failed to authenticate with AWS. Please run 'aws sso login' or 'aws configure' first.${NC}"
  exit 1
}

ACCOUNT_ID=$(echo "$CALLER_IDENTITY" | grep -o '"Account": "[^"]*' | cut -d'"' -f4)
echo -e "${GREEN}✓ Target Account ID:${NC} ${BOLD}${ACCOUNT_ID}${NC}"

# 3. Confirmation Prompt
echo -e "\n${BOLD}${RED}⚠️  WARNING: This will DESTROY all EC2 instances, RDS, ALB, security groups, IAM roles, S3 state, ECR images, and SSM parameters in account ${ACCOUNT_ID}.${NC}"
if [ "${CONFIRM_DESTROY:-}" != "true" ]; then
    echo -e "${YELLOW}========================================================================${NC}"
    echo -e "${YELLOW} SAFETY GUARD ACTIVATED: Destruction prevented.${NC}"
    echo -e "${YELLOW} To confirm destruction, you MUST pass CONFIRM_DESTROY=true${NC}"
    echo -e "${YELLOW} Run the command like this:${NC}"
    echo -e "${CYAN}   CONFIRM_DESTROY=true make destroy${NC}"
    echo -e "${YELLOW}========================================================================${NC}"
    exit 1
fi
echo -e "${GREEN}✓ CONFIRM_DESTROY=true provided. Proceeding with teardown...${NC}"

# 4. Initialize Terraform with S3 backend (needed to read current state)
echo -e "\n${YELLOW}📦 Initializing Terraform with remote backend...${NC}"
terraform -chdir=infra init -migrate-state -force-copy \
  -backend-config="bucket=absolute-tfstate-production" \
  -backend-config="key=state/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="encrypt=true" \
  -backend-config="use_lockfile=true" || {
  echo -e "${YELLOW}⚠️  Could not init with S3 backend (bucket may not exist). Trying local backend...${NC}"
  terraform -chdir=infra init -reconfigure -backend=false
}

# 5. Empty ECR repository BEFORE terraform destroy
# (Terraform cannot delete a non-empty ECR repo by default)
echo -e "\n${YELLOW}🗑️  Emptying ECR repository '${ECR_REPO_NAME}'...${NC}"
ECR_IMAGES=$(aws ecr list-images \
  --repository-name "$ECR_REPO_NAME" \
  --region "$AWS_REGION" \
  --query 'imageIds[*]' \
  --output json 2>/dev/null || echo "[]")

if [ "$ECR_IMAGES" != "[]" ] && [ "$ECR_IMAGES" != "null" ]; then
  aws ecr batch-delete-image \
    --repository-name "$ECR_REPO_NAME" \
    --region "$AWS_REGION" \
    --image-ids "$ECR_IMAGES" \
    --output json > /dev/null
  echo -e "${GREEN}✓ ECR images deleted.${NC}"
else
  echo -e "${CYAN}ℹ️  ECR repository is already empty or doesn't exist.${NC}"
fi

# 6. Migrate Terraform state to local disk
# We cannot destroy the S3 bucket if Terraform is currently using it for state.
# Migrating to local state allows us to empty and destroy the bucket safely.
echo -e "\n${YELLOW}📦 Migrating Terraform state to local...${NC}"
if [ -f "infra/backend.tf" ]; then
  mv infra/backend.tf infra/backend.tf.bak
  terraform -chdir=infra init -migrate-state -force-copy || true
fi

# 7. Empty the S3 state bucket BEFORE terraform destroy
# (S3 buckets with force_destroy = false cannot be deleted by Terraform if they contain objects)
echo -e "\n${YELLOW}🗑️  Emptying S3 bucket '${BUCKET_NAME}'...${NC}"
if aws s3 ls "s3://$BUCKET_NAME" --region "$AWS_REGION" > /dev/null 2>&1; then
  # Remove all object versions and delete markers (handles versioning)
  aws s3api list-object-versions \
    --bucket "$BUCKET_NAME" \
    --region "$AWS_REGION" \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
    --output json 2>/dev/null | \
    jq 'select(.Objects != null)' | \
    aws s3api delete-objects \
      --bucket "$BUCKET_NAME" \
      --region "$AWS_REGION" \
      --delete file:///dev/stdin > /dev/null 2>&1 || true

  # Remove any remaining delete markers
  aws s3api list-object-versions \
    --bucket "$BUCKET_NAME" \
    --region "$AWS_REGION" \
    --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
    --output json 2>/dev/null | \
    jq 'select(.Objects != null)' | \
    aws s3api delete-objects \
      --bucket "$BUCKET_NAME" \
      --region "$AWS_REGION" \
      --delete file:///dev/stdin > /dev/null 2>&1 || true

  echo -e "${GREEN}✓ S3 bucket emptied.${NC}"
else
  echo -e "${CYAN}ℹ️  S3 bucket '${BUCKET_NAME}' doesn't exist or is already empty.${NC}"
fi

# 8. Terraform Destroy
echo -e "\n${YELLOW}🔥 Running Terraform Destroy across all infrastructure...${NC}"
terraform -chdir=infra destroy -auto-approve

# 9. Restore backend.tf
if [ -f "infra/backend.tf.bak" ]; then
  echo -e "\n${YELLOW}📦 Restoring backend.tf...${NC}"
  mv infra/backend.tf.bak infra/backend.tf
fi

echo -e "\n${BOLD}${GREEN}=====================================================${NC}"
echo -e "${BOLD}${GREEN} 🧹 Total Teardown Complete! Zero AWS Resources Left ${NC}"
echo -e "${BOLD}${GREEN}=====================================================${NC}"
echo -e "All EC2 instances, RDS, ALB, security groups, IAM roles, ECR images, and storage have been destroyed."
