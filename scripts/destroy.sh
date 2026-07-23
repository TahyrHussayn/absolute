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
echo -e "\n${BOLD}${RED}⚠️  WARNING: This will DESTROY all EC2 instances, security groups, IAM roles, S3 state, and SSM parameters in account ${ACCOUNT_ID}.${NC}"
read -p "Are you sure you want to destroy ALL AWS resources? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Teardown cancelled.${NC}"
    exit 0
fi

# 4. Terraform Destroy
echo -e "\n${YELLOW}🔥 Running Terraform Destroy across all infrastructure...${NC}"
terraform -chdir=infra destroy -auto-approve

echo -e "\n${BOLD}${GREEN}=====================================================${NC}"
echo -e "${BOLD}${GREEN} 🧹 Total Teardown Complete! Zero AWS Resources Left ${NC}"
echo -e "${BOLD}${GREEN}=====================================================${NC}"
echo -e "All EC2 instances, security groups, IAM roles, and storage tables have been completely destroyed."
