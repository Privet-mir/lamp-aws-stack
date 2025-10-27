#!/bin/bash

# LAMP Stack Deployment Script
# This script automates the deployment process

set -e

echo "Starting LAMP Stack Deployment on AWS"
echo "========================================"

export AWS_PAGER=""
export AWS_CLI_AUTO_PROMPT=off

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "Terraform is not installed. Please install Terraform first."
    exit 1
fi

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "AWS CLI is not configured. Please run 'aws configure' first."
    exit 1
fi

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo "terraform.tfvars not found. Creating from example..."
    cp terraform.tfvars.example terraform.tfvars
    echo "terraform.tfvars created with example defaults."
    echo "   Customize later if needed:"
    echo "   - AWS region"
    echo "   - Instance types"
    echo "   - Network configuration"
    echo "   - Backend S3 settings (backend_bucket_name, backend_state_key)"
fi

BACKEND_BUCKET=$(terraform -chdir=. output -raw 2>/dev/null || true)

# Bootstrap remote backend S3
echo "Checking/creating backend S3 bucket..."

# Read backend vars from terraform.tfvars (fallback to defaults)
BACKEND_BUCKET_NAME=$(awk -F'=' '/backend_bucket_name/ {gsub(/"|\047| /, "", $2); print $2}' terraform.tfvars || true)
if [ -z "$BACKEND_BUCKET_NAME" ]; then BACKEND_BUCKET_NAME="assesment-sfeh123rasf1sdfa111"; fi
AWS_REGION_VAR=$(awk -F'=' '/aws_region/ {gsub(/"|\047| /, "", $2); print $2}' terraform.tfvars || echo "${AWS_DEFAULT_REGION}")

if [ -z "$AWS_REGION_VAR" ]; then
  echo "aws_region not set (and AWS_DEFAULT_REGION empty). Please set a region."
  exit 1
fi

echo "Using region: ${AWS_REGION_VAR}"

if ! aws s3api head-bucket --bucket "$BACKEND_BUCKET_NAME" 2>/dev/null; then
  echo "Creating S3 bucket: $BACKEND_BUCKET_NAME"
  if [ "$AWS_REGION_VAR" = "eu-central-1" ]; then
    aws s3api create-bucket --bucket "$BACKEND_BUCKET_NAME" --region "$AWS_REGION_VAR"
  else
    aws s3api create-bucket --bucket "$BACKEND_BUCKET_NAME" --region "$AWS_REGION_VAR" --create-bucket-configuration LocationConstraint="$AWS_REGION_VAR"
  fi
  aws s3api put-bucket-versioning --bucket "$BACKEND_BUCKET_NAME" --versioning-configuration Status=Enabled
  aws s3api put-bucket-encryption --bucket "$BACKEND_BUCKET_NAME" --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
else
  echo "S3 bucket already exists: $BACKEND_BUCKET_NAME"
fi


echo "Initializing Terraform..."
terraform init

echo "Planning deployment..."
terraform plan -out=tfplan -input=false

#Policy check: block plans that contain deletions
echo "Running OPA policy check..."
terraform show -json tfplan > tfplan.json
BLOCKED=false
if command -v conftest >/dev/null 2>&1; then
  conftest test tfplan.json -p policy/opa || BLOCKED=true
else
  if command -v jq >/dev/null 2>&1; then
    DELETE_COUNT=$(jq '[.resource_changes[]? | select(.change.actions[]? == "delete")] | length' tfplan.json)
    if [ "${DELETE_COUNT}" != "0" ]; then
      echo "Policy violation: Terraform plan attempts to delete ${DELETE_COUNT} resource(s)."
      BLOCKED=true
    fi
  else
    if grep -q '"delete"' tfplan.json; then
      echo "Policy violation: Terraform plan appears to include deletions (jq not installed)."
      BLOCKED=true
    fi
  fi
fi

if [ "$BLOCKED" = true ]; then
  echo "Aborting apply due to policy failure."
  exit 1
fi

echo "Deploying infrastructure..."
terraform apply -input=false -auto-approve tfplan

echo "Deployment completed!"
echo ""
echo "Deployment Summary:"
echo "====================="
terraform output

echo ""
echo "Access application endpoints:"
echo "=========================="
WEB_URL=$(terraform output -raw web_url 2>/dev/null || echo "Not available")
if [ "$WEB_URL" != "Not available" ]; then
    echo "   $WEB_URL"
    echo ""
    echo "Available endpoints:"
    echo "   - Homepage: $WEB_URL"
    echo "   - Fugro Application: $WEB_URL/sample_app.php"
    echo "   - Health Check: $WEB_URL/health.php"
else
    echo "   Load balancer DNS not available yet. Please check terraform output."
fi

echo "To clean up resources:"
echo "   terraform destroy"
echo ""
echo "LAMP Stack deployment completed successfully!"
