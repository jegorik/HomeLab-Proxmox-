# =============================================================================
# Terraform Provider Configuration - HashiCorp Vault LXC Container
# =============================================================================
#
# This file configures the Terraform providers required for deploying a
# HashiCorp Vault instance in a Proxmox LXC container with S3 state backend.
#
# Providers Used:
# - bpg/proxmox: Proxmox VE management (containers, VMs, storage)
# - hashicorp/aws: S3 backend for state storage
# - hashicorp/random: Secure password generation
#
# Provider: bpg/proxmox
# Documentation: https://registry.terraform.io/providers/bpg/proxmox/latest/docs
# GitHub: https://github.com/bpg/terraform-provider-proxmox
#
# Proxmox VE Compatibility:
#   - Tested with Proxmox VE 8.x
#   - Compatible with Proxmox VE 7.4+
#   - PVE 9.1+ supports OCI images for LXC (not used in this config)
#
# Authentication Methods (in order of preference):
#   1. API Token (recommended) - Set via proxmox_api_token variable
#   2. Username/Password - Not recommended for automation
#
# Required Proxmox Permissions for API Token (LXC):
#   Path: /
#   - Datastore.AllocateSpace (allocate disk space)
#   - Datastore.AllocateTemplate (download/use templates)
#   - Datastore.Audit (view storage)
#   - SDN.Use (use software-defined networking)
#   - Sys.Audit (view system info)
#   - Sys.Console (required for remote-exec provisioner)
#   - VM.Allocate (create new containers)
#   - VM.Audit (view containers)
#   - VM.Config.* (all config permissions)
#   - VM.PowerMgmt (start/stop/restart)
#
# API Token Creation:
#   Proxmox GUI -> Datacenter -> Permissions -> API Tokens -> Add
#   Format: user@realm!token_id
#
# Security Best Practices:
#   - Use API tokens with minimal required permissions (principle of least privilege)
#   - Store tokens in environment variables or secret managers (not in version control)
#   - Enable TLS verification in production (set insecure = false)
#   - Use SSH agent for secure key management
#   - Rotate API tokens periodically
#   - Use separate tokens for different projects/environments
#
# Author: HomeLab Infrastructure
# Provider Versions: proxmox 0.89.1, aws 6.26.0, random 3.6.x
# Last Updated: December 2025
# =============================================================================

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

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# -----------------------------------------------------------------------------
# Proxmox Provider Configuration
# -----------------------------------------------------------------------------

provider "proxmox" {
  # Proxmox VE API endpoint URL
  endpoint = var.proxmox_endpoint

  # API token in format: user@realm!token_id=secret
  api_token = var.proxmox_api_token

  # Skip TLS verification (set to false in production with valid certs)
  insecure = var.connection_insecure

  # SSH configuration for operations requiring direct host access
  # (e.g., container exec, template downloads)
  ssh {
    agent    = var.ssh_agent_enabled
    username = var.proxmox_ssh_user
  }
}

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
