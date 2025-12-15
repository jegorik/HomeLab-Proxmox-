# Terraform backend configuration for AWS S3 bucket state storage
#
# IMPORTANT: Variables cannot be used in backend blocks. Instead, use:
# 1. Backend config file: tofu init -backend-config=s3.backend.config
# 2. Environment variables: AWS_DEFAULT_REGION, AWS_ACCESS_KEY_ID, etc.
# 3. CLI flags: tofu init -backend-config="key=value"
#
# See s3.backend.config for backend configuration parameters


terraform {
  backend "s3" {
    region = var.aws_region
  }
}
  # Backend block will be configured via -backend-config flag or backend config file
  # This prevents hardcoding sensitive values