#!/usr/bin/env bash
# ==============================================================================
# Absolute — Day 0 AWS Infrastructure & OIDC Keyless Bootstrap Script
# ==============================================================================
# This script performs the initial Day 0 provisioning of the Terraform S3 backend,
# DynamoDB lock table, and GitHub Actions OIDC identity provider in your AWS Account.
#
# Usage:
#   ./scripts/bootstrap.sh
# ==============================================================================

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BOLD}${CYAN}=====================================================${NC}"
echo -e "${BOLD}${CYAN} 🚀 Absolute — Day 0 AWS Infrastructure Bootstrap   ${NC}"
echo -e "${BOLD}${CYAN}=====================================================${NC}"

# 1. Prerequisite Checks
command -v aws >/dev/null 2>&1 || { echo -e "${RED}❌ AWS CLI is required but not installed.${NC}"; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo -e "${RED}❌ Terraform CLI is required but not installed.${NC}"; exit 1; }

# 2. Verify AWS Authentication
echo -e "\n${YELLOW}🔍 Checking AWS caller identity...${NC}"
CALLER_IDENTITY=$(aws sts get-caller-identity --output json 2>/dev/null) || {
  echo -e "${RED}❌ Failed to authenticate with AWS. Please run 'aws sso login' or 'aws configure' first.${NC}"
  exit 1
}

ACCOUNT_ID=$(echo "$CALLER_IDENTITY" | grep -o '"Account": "[^"]*' | cut -d'"' -f4)
ARN=$(echo "$CALLER_IDENTITY" | grep -o '"Arn": "[^"]*' | cut -d'"' -f4)

echo -e "${GREEN}✓ Authenticated as:${NC} ${BOLD}${ARN}${NC}"
echo -e "${GREEN}✓ AWS Account ID:${NC}   ${BOLD}${ACCOUNT_ID}${NC}"

# 3. Initialize Terraform
echo -e "\n${YELLOW}📦 Initializing Terraform in infra/...${NC}"
terraform -chdir=infra init -reconfigure

# 4. Target Bootstrap Resources & Sync Remote State
echo -e "\n${YELLOW}🏗️ Provisioning S3 Backend, DynamoDB Locks, and OIDC Keyless Role...${NC}"
terraform -chdir=infra apply \
  -target=aws_s3_bucket.tf_state \
  -target=aws_dynamodb_table.tf_locks \
  -target=aws_iam_openid_connect_provider.github \
  -target=aws_iam_role.github_actions \
  -target=aws_iam_role_policy_attachment.github_actions_admin \
  -auto-approve

echo -e "\n${YELLOW}🔄 Synchronizing Full Infrastructure State to S3 Remote Backend...${NC}"
terraform -chdir=infra apply -auto-approve

echo -e "\n${BOLD}${GREEN}=====================================================${NC}"
echo -e "${BOLD}${GREEN} 🎉 Day 0 AWS Bootstrap Complete!                    ${NC}"
echo -e "${BOLD}${GREEN}=====================================================${NC}"
echo -e "Next steps for automated deployment:"
echo -e "1. Go to your GitHub repository: ${CYAN}Settings ➔ Secrets and variables ➔ Actions${NC}"
echo -e "2. Add a new repository secret:"
echo -e "   - Name:  ${BOLD}AWS_ACCOUNT_ID${NC}"
echo -e "   - Value: ${BOLD}${ACCOUNT_ID}${NC}"
echo -e "3. Push any commit to ${BOLD}main${NC} — GitHub Actions will deploy automatically via Keyless OIDC!"
