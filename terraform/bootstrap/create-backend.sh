#!/usr/bin/env bash
# Run ONCE before terraform init to create the S3 backend and DynamoDB lock table.
set -euo pipefail

ACCOUNT_ID="803146828684"
REGION="ap-south-1"
BUCKET="microservices-demo-tfstate-${ACCOUNT_ID}-${REGION}"
TABLE="microservices-demo-tfstate-lock"

echo "==> Creating S3 bucket: ${BUCKET}"
aws s3api create-bucket \
  --bucket "${BUCKET}" \
  --region "${REGION}" \
  --create-bucket-configuration LocationConstraint="${REGION}"

echo "==> Enabling versioning"
aws s3api put-bucket-versioning \
  --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled

echo "==> Enabling AES256 encryption"
aws s3api put-bucket-encryption \
  --bucket "${BUCKET}" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

echo "==> Blocking all public access"
aws s3api put-public-access-block \
  --bucket "${BUCKET}" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "==> Creating DynamoDB lock table: ${TABLE}"
aws dynamodb create-table \
  --table-name "${TABLE}" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "${REGION}"

echo ""
echo "✅ Backend ready. Now run:"
echo "   cd terraform/environments/dev && terraform init"
