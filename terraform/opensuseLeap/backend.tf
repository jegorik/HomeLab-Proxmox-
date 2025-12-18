# =============================================================================
# Terraform/OpenTofu Backend Configuration - AWS S3 State Storage
# =============================================================================
# This file configures remote state storage in AWS S3 with optional DynamoDB
# locking to prevent concurrent modifications.
#
# Why Use Remote State?
# - Team Collaboration: Share state across team members
# - State Locking: Prevent concurrent modifications (requires S3 native lock or DynamoDB)
# - Backup: S3 versioning provides automatic state backups
# - Security: Encrypt state at rest with S3 encryption
# - Disaster Recovery: State survives local machine failures
#
# IMPORTANT LIMITATIONS:
# - Variables CANNOT be used in backend blocks (Terraform restriction)
# - Must use alternative configuration methods (see below)
# - Backend configuration is parsed before variable evaluation
#
# Configuration Methods:
#
# Method 1: Backend Config File (Recommended)
#   Create s3.backend.config with your settings:
#     bucket         = "my-terraform-state"
#     key            = "opensuseLeap15.6/terraform.tfstate"
#     region         = "eu-west-1"
#     encrypt        = true
#     dynamodb_table = "terraform-state-lock"
#     # S3 enable state locking
#     use_lockfile = true
#
#   Initialize with:
#     tofu init -backend-config=s3.backend.config
#
# Method 2: Environment Variables
#   export AWS_DEFAULT_REGION="eu-west-1"
#   export AWS_ACCESS_KEY_ID="your-access-key"
#   export AWS_SECRET_ACCESS_KEY="your-secret-key"
#   tofu init
#
# Method 3: CLI Flags
#   tofu init \
#     -backend-config="bucket=my-terraform-state" \
#     -backend-config="key=opensuseLeap15.6/terraform.tfstate" \
#     -backend-config="region=eu-west-1" \
#     -backend-config="encrypt=true"
#
# S3 Backend Setup Guide:
#
# Step 1: Create S3 bucket for state storage
#   aws s3 mb s3://my-terraform-state --region eu-west-1
#
# Step 2: Enable versioning (recommended for state history)
#   aws s3api put-bucket-versioning \
#     --bucket my-terraform-state \
#     --versioning-configuration Status=Enabled
#
# Step 3: Enable encryption (recommended for security)
#   aws s3api put-bucket-encryption \
#     --bucket my-terraform-state \
#     --server-side-encryption-configuration \
#     '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
#
# Step 4: Create DynamoDB table for state locking (optional but recommended)
#   aws dynamodb create-table \
#     --table-name terraform-state-lock \
#     --attribute-definitions AttributeName=LockID,AttributeType=S \
#     --key-schema AttributeName=LockID,KeyType=HASH \
#     --billing-mode PAY_PER_REQUEST \
#     --region eu-west-1
#
# Step 5: Create s3.backend.config file (see example in repository)
#
# Step 6: Initialize backend
#   tofu init -backend-config=s3.backend.config
#
# Migrating from Local to Remote State:
#   1. Configure backend as shown above
#   2. Run: tofu init -migrate-state
#   3. Confirm migration when prompted
#   4. Verify: aws s3 ls s3://my-terraform-state/
#
# Troubleshooting:
#
# Issue: "Error loading state: AccessDenied"
# Solution: Verify AWS credentials and S3 bucket permissions
#   aws s3 ls s3://my-terraform-state/  # Test access
#
# Issue: "Error acquiring the state lock"
# Solution: Check DynamoDB table exists and is accessible
#   aws dynamodb describe-table --table-name terraform-state-lock
#
# Issue: "Backend initialization required"
# Solution: Run tofu init with backend config
#   tofu init -backend-config=s3.backend.config -reconfigure
#
# Security Considerations:
# - Enable S3 bucket encryption at rest
# - Enable S3 versioning for state history
# - Use IAM policies to restrict access
# - Enable CloudTrail for audit logging
# - Consider S3 bucket policies to restrict access by IP
# - Use MFA Delete for production state buckets
# =============================================================================

terraform {
  backend "s3" {
    # Backend configuration will be provided via:
    # - s3.backend.config file
    # - Environment variables
    # - CLI flags during init
    #
    # This empty block declares we're using S3 backend
    # Actual values must be provided externally
  }
}

# Example s3.backend.config file contents:
# ==========================================
# bucket         = "my-terraform-state"
# key            = "opensuseLeap15.6/terraform.tfstate"
# region         = "eu-west-1"
# encrypt        = true
# dynamodb_table = "terraform-state-lock"
# ==========================================
