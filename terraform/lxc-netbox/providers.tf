terraform {
  required_providers {
    # Proxmox VE provider for VM and container management
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.90.0"
    }

    # AWS provider for S3 backend and optional resource management
    aws = {
      source  = "hashicorp/aws"
      version = "6.27.0"
    }

    # Vault provider for secrets management
    vault = {
      source  = "hashicorp/vault"
      version = "5.6.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
  }
}

# -----------------------------------------------------------------------------
# Vault Provider Configuration
# -----------------------------------------------------------------------------

provider "vault" {
  # Vault server address
  address = var.vault_address

  # Skip TLS verification (set to false in production with valid certs)
  skip_tls_verify = var.vault_skip_tls_verify

  skip_child_token = true

  # Authentication using token from VAULT_TOKEN environment variable
  # Token is set by sourcing vault_init.sh which authenticates via userpass
  # and exports VAULT_TOKEN to the environment
}

# -----------------------------------------------------------------------------
# Vault Data Sources - Retrieve Secrets from Vault
# -----------------------------------------------------------------------------
# Note: These use data sources because they're referenced in provider configuration
# and resource attributes that persist in state. Ephemeral resources are only
# supported in write-only contexts (provisioners, sensitive provider settings).

# Retrieve Proxmox endpoint URL from Vault
data "vault_generic_secret" "proxmox_endpoint" {
  path = var.proxmox_endpoint_vault_path
}

# Retrieve Proxmox node name from Vault
data "vault_generic_secret" "proxmox_node_name" {
  path = var.proxmox_node_name_vault_path
}

# Retrieve Proxmox user from Vault
data "vault_generic_secret" "proxmox_user" {
  path = var.proxmox_user_name_vault_path
}

# Retrieve SSH root public key from Vault
data "vault_generic_secret" "root_ssh_public_key" {
  path = var.root_ssh_public_key_path
}

# Retrieve SSH Ansible public key from Vault
data "vault_generic_secret" "ansible_ssh_public_key" {
  path = var.ansible_ssh_public_key_path
}

# -----------------------------------------------------------------------------
# Ephemeral Resources - For Write-Only Contexts
# -----------------------------------------------------------------------------
# These are used in provisioner connections where ephemeral values are supported

# Retrieve Proxmox API token from Vault
ephemeral "vault_kv_secret_v2" "proxmox_api_token" {
  mount = var.ephemeral_vault_mount_path
  name  = var.proxmox_api_token_vault_path
}

# Retrieve SSH root private key from Vault
ephemeral "vault_kv_secret_v2" "root_ssh_private_key" {
  mount = var.ephemeral_vault_mount_path
  name  = var.root_ssh_private_key_path
}

# -----------------------------------------------------------------------------
# Proxmox Provider Configuration
# -----------------------------------------------------------------------------

provider "proxmox" {
  # Proxmox VE API endpoint URL (from Vault)
  endpoint = data.vault_generic_secret.proxmox_endpoint.data["url"]

  # API token in format: user@realm!token_id=secret (from Vault)
  # api_token = data.vault_generic_secret.proxmox_api_token.data["token"]
  api_token = ephemeral.vault_kv_secret_v2.proxmox_api_token.data["token"]

  # Skip TLS verification (set to false in production with valid certs)
  insecure = var.connection_insecure

  # SSH configuration for operations requiring direct host access
  # (e.g., container exec, template downloads)
  ssh {
    agent    = var.ssh_agent_enabled
    username = data.vault_generic_secret.proxmox_user.data["username"]
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
