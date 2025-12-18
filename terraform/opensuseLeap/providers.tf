# =============================================================================
# OpenTofu Provider Configuration
# =============================================================================
# This file configures the required providers and their settings for managing
# Proxmox VE infrastructure and optionally AWS resources for state storage.
#
# Providers:
# - Proxmox: bpg/proxmox v0.89.1 - Manages VMs, containers, and resources
# - AWS: hashicorp/aws v6.26.0 - For S3 backend and optional services
#
# Authentication:
# - Proxmox: API token authentication with optional SSH for file operations
# - AWS: Credentials from environment variables or AWS CLI configuration
#
# Security Considerations:
# - API tokens should be created with minimal required permissions
# - Use environment variables for sensitive values (TF_VAR_*)
# - Enable MFA for AWS credentials in production
# - Set insecure=false in production (requires proper TLS certificates)
# - Store credentials in HashiCorp Vault or AWS Secrets Manager
#
# References:
# - Proxmox Provider: https://github.com/bpg/terraform-provider-proxmox
# - AWS Provider: https://registry.terraform.io/providers/hashicorp/aws
# =============================================================================

# -----------------------------------------------------------------------------
# Required Providers and Version Constraints
# -----------------------------------------------------------------------------

terraform {
  required_providers {
    # Proxmox VE provider for VM and container management
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.89.1"
    }

    # AWS provider for S3 backend and optional resource management
    aws = {
      source  = "hashicorp/aws"
      version = "6.26.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Proxmox Provider Configuration
# -----------------------------------------------------------------------------
# Configures connection to Proxmox VE API and SSH access for file operations
#
# Authentication: Uses API token (format: user@realm!token-id=secret)
# SSH Access: Required for uploading cloud-init snippets and files
# TLS: Configurable certificate validation
#
# Security Best Practices:
# 1. Use environment variables for credentials:
#    export TF_VAR_proxmox_api_token="terraform@pve!token=secret"
# 2. Never commit terraform.tfvars with real tokens
# 3. Set insecure=false in production (requires valid TLS certificates)
# 4. Rotate API tokens regularly
# 5. Use separate tokens per environment (dev/staging/prod)

provider "proxmox" {
  # Proxmox VE API endpoint URL
  # Format: https://hostname-or-ip:8006/
  # Example: https://192.168.1.100:8006/
  endpoint = var.proxmox_endpoint

  # API token in format: user@realm!token_id=secret
  # Create in Proxmox UI: Datacenter > API Tokens > Add
  # Example: terraform@pve!terraform-token=12345678-abcd-efgh-ijkl-mnopqrstuvwx
  # SECURITY: Use environment variable TF_VAR_proxmox_api_token instead
  api_token = var.proxmox_api_token

  # Skip TLS certificate verification
  # Development: true (allows self-signed certificates)
  # Production: false (requires valid CA-signed certificates)
  # To use valid certs, add Proxmox CA to system trust store or specify cert path
  insecure = var.connection_option_insecure

  # SSH configuration for direct host operations
  # Required for: cloud-init snippet uploads, ISO file uploads
  # Uses either SSH agent or private key file
  ssh {
    agent       = var.ssh_agent_option                     # Use SSH agent (recommended)
    username    = var.proxmox_user                         # SSH username (usually 'root' or 'terraform')
    private_key = file(var.terraform_ssh_private_key_path) # Path to private key (~/.ssh/id_rsa or ~/.ssh/proxmox_terraform)
  }
}

# -----------------------------------------------------------------------------
# AWS Provider Configuration
# -----------------------------------------------------------------------------
# Configures AWS provider for S3 backend state storage and optional services.
#
# Authentication Methods (in order of precedence):
# 1. Environment variables:
#    - AWS_ACCESS_KEY_ID
#    - AWS_SECRET_ACCESS_KEY
#    - AWS_SESSION_TOKEN (for temporary credentials)
#
# 2. AWS CLI credentials file (~/.aws/credentials):
#    [default]
#    aws_access_key_id = YOUR_ACCESS_KEY
#    aws_secret_access_key = YOUR_SECRET_KEY
#
# 3. IAM role (when running on EC2 instances or ECS tasks)
#    - Automatically uses instance/task role credentials
#    - Most secure method for AWS-hosted infrastructure
#
# 4. AWS CLI profile (specified in code):
#    profile = "terraform"  # Uses [terraform] section from ~/.aws/credentials
#
# Security Best Practices:
# - Never hardcode credentials in Terraform files
# - Use IAM roles when running in AWS
# - Use environment variables for CI/CD pipelines
# - Enable MFA for AWS accounts with Terraform access
# - Use separate AWS accounts for dev/staging/prod
# - Implement least-privilege IAM policies
#
# Practical Examples:
#
# Example 1: Using environment variables (CI/CD)
#   export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
#   export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
#   export AWS_DEFAULT_REGION="eu-west-1"
#   tofu init -backend-config=s3.backend.config
#
# Example 2: Using AWS CLI profile
#   # In ~/.aws/credentials:
#   [terraform]
#   aws_access_key_id = AKIAIOSFODNN7EXAMPLE
#   aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
#
#   # In terraform.tfvars:
#   aws_profile = "terraform"
#
# Example 3: Using IAM role (EC2/ECS)
#   # No credentials needed - automatically uses instance role
#   # Requires IAM role attached to EC2 instance with S3 permissions

provider "aws" {
  # AWS region for S3 backend and resource deployment
  # Choose region closest to your infrastructure for better performance
  # Common regions:
  #   - us-east-1 (N. Virginia)
  #   - eu-west-1 (Ireland)
  #   - eu-central-1 (Frankfurt)
  #   - ap-southeast-1 (Singapore)
  region = var.aws_region

  # Optional: AWS CLI profile to use
  # Uncomment and set var.aws_profile in terraform.tfvars
  # profile = var.aws_profile
}
