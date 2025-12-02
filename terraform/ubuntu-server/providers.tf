# =============================================================================
# Terraform Provider Configuration - Proxmox VE
# =============================================================================
#
# This file configures the Terraform providers required for Proxmox VE
# infrastructure management.
#
# Provider: bpg/proxmox
# Documentation: https://registry.terraform.io/providers/bpg/proxmox/latest/docs
# GitHub: https://github.com/bpg/terraform-provider-proxmox
#
# Authentication Methods (in order of preference):
#   1. API Token (recommended) - Set via proxmox_api_token variable
#   2. Username/Password - Not recommended for automation
#
# Security Best Practices:
#   - Use API tokens with minimal required permissions
#   - Store tokens in environment variables or secret managers
#   - Enable TLS verification in production (insecure = false)
#   - Use SSH agent for secure key management
#
# Required Proxmox Permissions for API Token:
#   - Datastore.AllocateSpace
#   - Datastore.AllocateTemplate
#   - Datastore.Audit
#   - SDN.Use
#   - Sys.Audit
#   - VM.Allocate
#   - VM.Audit
#   - VM.Clone
#   - VM.Config.*
#   - VM.PowerMgmt
#
# Author: HomeLab Infrastructure
# Provider Version: 0.88.0 (December 2025)
# =============================================================================

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.88.0"
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

  # Skip TLS verification (set to false in production)
  insecure = var.connection_option_insecure

  # SSH configuration for operations requiring direct host access
  # (e.g., cloud-init snippets, ISO uploads)
  ssh {
    agent    = var.ssh_agent_option # Use SSH agent for key management
    username = var.proxmox_user     # SSH username for Proxmox host
  }
}