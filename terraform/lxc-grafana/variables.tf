# =============================================================================
# Input Variables - LXC Grafana Container
# =============================================================================
#
# This file defines all input variables for the Grafana LXC container
# deployment on Proxmox VE. Variables are organized into logical sections
# for easier management and documentation.
#
# Variable Naming Convention:
#   - proxmox_*     : Proxmox connection settings
#   - lxc_*         : LXC container configuration
#   - grafana_*     : Grafana-specific settings
#   - ssh_*         : SSH configuration
#
# Security Notes:
#   - Variables marked 'sensitive = true' won't appear in logs
#   - Store sensitive values in terraform.tfvars (not committed)
#   - Use environment variables for CI/CD: TF_VAR_<variable_name>
#
# Author: HomeLab Infrastructure
# Last Updated: December 2025
# =============================================================================

# -----------------------------------------------------------------------------
# Proxmox Connection Variables
# -----------------------------------------------------------------------------

variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint URL (e.g., https://192.168.1.100:8006)"
  type        = string

  validation {
    condition     = can(regex("^https://", var.proxmox_endpoint))
    error_message = "Proxmox endpoint must use HTTPS protocol."
  }
}

variable "proxmox_api_token" {
  description = "Proxmox API token in format: user@realm!token_id=secret"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^.+@.+!.+=.+$", var.proxmox_api_token))
    error_message = "API token must be in format: user@realm!token_id=secret"
  }
}

variable "proxmox_node" {
  description = "Proxmox node name where the container will be created"
  type        = string
  default     = "pve"
}

variable "proxmox_ssh_user" {
  description = "SSH username for Proxmox host (for provisioner access)"
  type        = string
  default     = "root"
}

variable "connection_insecure" {
  description = "Skip TLS certificate verification (set false in production)"
  type        = bool
  default     = true
}

variable "ssh_agent_enabled" {
  description = "Use SSH agent for authentication"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# LXC Container Identity Variables
# -----------------------------------------------------------------------------

variable "lxc_id" {
  description = "Unique container ID (VMID) in Proxmox"
  type        = number
  default     = 200

  validation {
    condition     = var.lxc_id >= 100 && var.lxc_id <= 999999999
    error_message = "Container ID must be between 100 and 999999999."
  }
}

variable "lxc_hostname" {
  description = "Container hostname"
  type        = string
  default     = "grafana"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,62}$", var.lxc_hostname))
    error_message = "Hostname must start with letter, contain only lowercase letters, numbers, hyphens, max 63 chars."
  }
}

variable "lxc_description" {
  description = "Container description shown in Proxmox GUI"
  type        = string
  default     = "Grafana monitoring dashboard - Managed by OpenTofu"
}

variable "lxc_tags" {
  description = "Tags for container organization in Proxmox"
  type        = list(string)
  default     = ["grafana", "monitoring", "tofu-managed"]
}

# -----------------------------------------------------------------------------
# LXC Container Resource Variables
# -----------------------------------------------------------------------------

variable "lxc_cpu_cores" {
  description = "Number of CPU cores allocated to the container"
  type        = number
  default     = 1

  validation {
    condition     = var.lxc_cpu_cores >= 1 && var.lxc_cpu_cores <= 128
    error_message = "CPU cores must be between 1 and 128."
  }
}

variable "lxc_memory" {
  description = "Dedicated memory in MB"
  type        = number
  default     = 1024

  validation {
    condition     = var.lxc_memory >= 512
    error_message = "Minimum memory is 512 MB for Grafana."
  }
}

variable "lxc_swap" {
  description = "Swap memory in MB (0 to disable)"
  type        = number
  default     = 512
}

variable "lxc_disk_size" {
  description = "Root filesystem size in GB"
  type        = number
  default     = 8

  validation {
    condition     = var.lxc_disk_size >= 4
    error_message = "Minimum disk size is 4 GB for Grafana."
  }
}

variable "lxc_disk_storage" {
  description = "Storage pool for container rootfs (e.g., local-lvm, local-zfs)"
  type        = string
  default     = "local-lvm"
}

# -----------------------------------------------------------------------------
# LXC Container Template Variables
# -----------------------------------------------------------------------------

variable "lxc_template_storage" {
  description = "Storage pool containing LXC templates"
  type        = string
  default     = "local"
}

variable "lxc_template_file" {
  description = "LXC template filename (must exist on Proxmox)"
  type        = string
  default     = "ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
}

# -----------------------------------------------------------------------------
# LXC Container Network Variables
# -----------------------------------------------------------------------------

variable "lxc_network_bridge" {
  description = "Network bridge to attach container to"
  type        = string
  default     = "vmbr0"
}

variable "lxc_ip_address" {
  description = "IPv4 address with CIDR (e.g., 192.168.1.50/24) or 'dhcp'"
  type        = string
  default     = "dhcp"
}

variable "lxc_gateway" {
  description = "Default gateway IP (required if using static IP)"
  type        = string
  default     = ""
}

variable "lxc_dns_servers" {
  description = "DNS servers (space-separated)"
  type        = string
  default     = "8.8.8.8 8.8.4.4"
}

# -----------------------------------------------------------------------------
# LXC Container Security Variables
# -----------------------------------------------------------------------------

variable "lxc_unprivileged" {
  description = "Run as unprivileged container (recommended for security)"
  type        = bool
  default     = true
}

variable "lxc_start_on_boot" {
  description = "Start container automatically on Proxmox boot"
  type        = bool
  default     = true
}

variable "lxc_protection" {
  description = "Protect container from accidental deletion"
  type        = bool
  default     = false
}

variable "lxc_nesting" {
  description = "Enable nesting (required for systemd in container)"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# LXC Container User Variables
# -----------------------------------------------------------------------------

variable "lxc_root_password" {
  description = "Root password for container (leave empty to generate)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file for root access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

# -----------------------------------------------------------------------------
# Grafana Configuration Variables
# -----------------------------------------------------------------------------

variable "grafana_port" {
  description = "Grafana HTTP port"
  type        = number
  default     = 3000

  validation {
    condition     = var.grafana_port >= 1024 && var.grafana_port <= 65535
    error_message = "Grafana port must be between 1024 and 65535."
  }
}

variable "grafana_admin_user" {
  description = "Grafana admin username"
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana admin password (leave empty to generate)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "grafana_version" {
  description = "Grafana version to install (latest or specific version)"
  type        = string
  default     = "latest"
}

variable "grafana_allow_anonymous" {
  description = "Allow anonymous access to dashboards"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Password Generation Variables
# -----------------------------------------------------------------------------

variable "password_length" {
  description = "Length of generated passwords"
  type        = number
  default     = 16

  validation {
    condition     = var.password_length >= 12
    error_message = "Password must be at least 12 characters for security."
  }
}

variable "password_special_chars" {
  description = "Special characters allowed in generated passwords"
  type        = string
  default     = "!@#$%^&*"
}
