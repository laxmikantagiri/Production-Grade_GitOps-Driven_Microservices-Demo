#!/usr/bin/env bash

set -euo pipefail

# ==============================================================================
# SRE Bootstrap Script: Terraform Backend Infrastructure Setup
# ==============================================================================

AWS_REGION="ap-south-1"
BUCKET_NAME="boutique-tfstate-803146828684-ap-south-1"
DYNAMODB_TABLE="boutique-tfstate-lock"

echo "Initializing cloud resources for Terraform backend state tracking..."

# Check and create S3 bucket
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
    echo "S3 state bucket '${BUCKET_NAME}' already exists."
else
    echo "Creating secure S3 state bucket '${BUCKET_NAME}'..."
    # If region is us-east-1, location constraint must not be specified
    if [ "${AWS_REGION}" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --region "${AWS_REGION}"
    else
        aws s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --region "${AWS_REGION}" \
            --create-bucket-configuration LocationConstraint="${AWS_REGION}"
    fi

    # Enforce Server-Side Encryption (SSE)
    aws s3api put-bucket-encryption \
        --bucket "${BUCKET_NAME}" \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        }'

    # Block all public access explicitly
    aws s3api put-public-access-block \
        --bucket "${BUCKET_NAME}" \
        --public-access-block-configuration '{
            "BlockPublicAcls": true,
            "IgnorePublicAcls": true,
            "BlockPublicPolicy": true,
            "RestrictPublicBuckets": true
        }'

    # Enable versioning for state rollbacks
    aws s3api put-bucket-versioning \
        --bucket "${BUCKET_NAME}" \
        --versioning-configuration Status=Enabled

    echo "S3 state bucket '${BUCKET_NAME}' created and locked down successfully."
fi

# Check and create DynamoDB table for state locking
if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${AWS_REGION}" >/dev/null 2>&1; then
    echo "DynamoDB lock table '${DYNAMODB_TABLE}' already exists."
else
    echo "Creating DynamoDB state lock table '${DYNAMODB_TABLE}'..."
    aws dynamodb create-table \
        --table-name "${DYNAMODB_TABLE}" \
        --region "${AWS_REGION}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST

    echo "Waiting for DynamoDB lock table to transition to ACTIVE state..."
    aws dynamodb wait table-exists \
        --table-name "${DYNAMODB_TABLE}" \
        --region "${AWS_REGION}"
    
    echo "DynamoDB state lock table '${DYNAMODB_TABLE}' is now ACTIVE."
fi

echo "Infrastructure bootstrap complete. Ready for 'terraform init'."
