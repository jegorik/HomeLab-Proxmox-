# =============================================================================
# Terraform Provider Configuration - Proxmox VE (LXC Grafana)
# =============================================================================
#
# This file configures the Terraform providers required for Proxmox VE
# LXC container management.
#
# Provider: bpg/proxmox
# Documentation: https://registry.terraform.io/providers/bpg/proxmox/latest/docs
# GitHub: https://github.com/bpg/terraform-provider-proxmox
#
# Proxmox VE Compatibility:
#   - Tested with Proxmox VE 8.x and 9.x
#   - PVE 9.1+ supports OCI images for LXC (not used in this config)
#
# Authentication Methods (in order of preference):
#   1. API Token (recommended) - Set via proxmox_api_token variable
#   2. Username/Password - Not recommended for automation
#
# Required Proxmox Permissions for API Token (LXC):
#   - Datastore.AllocateSpace
#   - Datastore.AllocateTemplate
#   - Datastore.Audit
#   - SDN.Use
#   - Sys.Audit
#   - Sys.Console (for exec provisioner)
#   - VM.Allocate
#   - VM.Audit
#   - VM.Config.*
#   - VM.PowerMgmt
#
# Security Best Practices:
#   - Use API tokens with minimal required permissions
#   - Store tokens in environment variables or secret managers
#   - Enable TLS verification in production (insecure = false)
#   - Use SSH agent for secure key management
#
# Author: HomeLab Infrastructure
# Provider Version: 0.88.0 (December 2025)
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.88.0"
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
