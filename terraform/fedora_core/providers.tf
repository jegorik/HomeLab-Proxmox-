# =============================================================================
# Terraform Provider Configuration - Proxmox VE (Fedora CoreOS VM)
# =============================================================================
#
# This file configures the OpenTofu/Terraform providers required for Fedora
# CoreOS VM provisioning on Proxmox VE.
#
# Providers:
#   - bpg/proxmox: Proxmox VE API and SSH operations
#   - poseidon/ct: Butane to Ignition transpilation
#   - hashicorp/random: Secure password generation
#   - hashicorp/null: Local-exec provisioners
#   - hashicorp/local: Local file operations
#
# Documentation:
#   - bpg/proxmox: https://registry.terraform.io/providers/bpg/proxmox/latest
#   - poseidon/ct: https://registry.terraform.io/providers/poseidon/ct/latest
#   - Fedora CoreOS: https://docs.fedoraproject.org/en-US/fedora-coreos/
#
# Proxmox VE Compatibility:
#   - Tested with Proxmox VE 8.x and 9.x
#
# ⚠️  IMPORTANT: Fedora CoreOS with Ignition requires kvm_arguments
# The kvm_arguments parameter requires ROOT user with PASSWORD authentication
# API Tokens do NOT work for kvm_arguments! This is a Proxmox limitation.
#
# Authentication Setup:
#   export PROXMOX_VE_USERNAME="root@pam"
#   export PROXMOX_VE_PASSWORD="your_password"
#
# Required Proxmox Permissions:
#   - Root user (for kvm_arguments support)
#   - Or API token user with Sys.Modify on /nodes (may not work for args)
#
# Author: HomeLab Infrastructure
# Provider Versions: December 2025
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    # Proxmox VE provider for VM management
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.88"
    }

    # CoreOS Config Transpiler - converts Butane YAML to Ignition JSON
    ct = {
      source  = "poseidon/ct"
      version = "~> 0.13"
    }

    # Random provider for password generation
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }

    # Null provider for local-exec provisioners
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }

    # Local provider for file operations
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

# -----------------------------------------------------------------------------
# Proxmox Provider Configuration
# -----------------------------------------------------------------------------
# Note: For Fedora CoreOS with Ignition, we need kvm_arguments which requires
# root@pam authentication (not API tokens). Use environment variables:
#   PROXMOX_VE_USERNAME="root@pam"
#   PROXMOX_VE_PASSWORD="your_password"
# -----------------------------------------------------------------------------

provider "proxmox" {
  # Proxmox VE API endpoint URL
  endpoint = var.proxmox_api_url

  # Authentication via API token
  api_token = var.proxmox_api_token != "" ? var.proxmox_api_token : null

  # Skip TLS verification (set to false in production with valid certs)
  insecure = var.proxmox_insecure

  # SSH configuration for operations requiring direct host access
  # (e.g., qemu-img convert for disk import)
  # Uses 'ansible' user created by scripts/bash/setup/ansible_user_setup.sh
  #
  # When running via Semaphore UI: pass private_key content via variable
  # When running locally: uses SSH agent (private_key empty)
  ssh {
    agent       = var.proxmox_ssh_private_key == "" ? true : false
    username    = var.proxmox_ssh_username
    private_key = var.proxmox_ssh_private_key != "" ? var.proxmox_ssh_private_key : null
  }
}

# -----------------------------------------------------------------------------
# CoreOS Config Transpiler Provider
# -----------------------------------------------------------------------------
# No configuration required - used as data source for Butane transpilation
# -----------------------------------------------------------------------------
provider "ct" {}
