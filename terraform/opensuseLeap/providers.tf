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

provider "proxmox" {
  # Proxmox VE API endpoint URL
  endpoint = var.proxmox_endpoint

  # API token in format: user@realm!token_id=secret
  api_token = var.proxmox_api_token

  # Skip TLS verification (set to false in production)
  insecure = var.connection_option_insecure

  # SSH configuration for operations requiring direct host access
  # (e.g., cloud-init snippets, ISO uploads)
  ssh {
    agent    = var.ssh_agent_option # Use SSH agent for key management
    username = var.proxmox_user     # SSH username for Proxmox host
  }
}

# -----------------------------------------------------------------------------
# AWS Provider Configuration
# -----------------------------------------------------------------------------
# Configures AWS provider for S3 backend state storage and optional services.
# Authentication methods (in order of precedence):
# 1. Environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
# 2. AWS CLI credentials file: ~/.aws/credentials
# 3. IAM role (when running on EC2 instances)
#
# Security: Never hardcode credentials in Terraform files

provider "aws" {
  # AWS region for S3 backend and resource deployment
  # Common regions: us-east-1, eu-central-1, ap-southeast-1
  region = var.aws_region

  # Optional: AWS CLI profile to use (set via var.aws_profile)
  # profile = var.aws_profile
}
