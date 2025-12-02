# =============================================================================
# Ubuntu Server VM - Variables Definition
# =============================================================================
#
# This file defines all input variables for the Ubuntu Server VM module.
# Variables are organized into logical groups for better maintainability.
#
# Security Best Practices:
# - Sensitive variables are marked with `sensitive = true`
# - Never commit actual values to version control
# - Use terraform.tfvars (gitignored) or environment variables for secrets
#
# =============================================================================

# -----------------------------------------------------------------------------
# Proxmox Connection Variables
# -----------------------------------------------------------------------------

variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint URL (e.g., https://192.168.1.100:8006/)"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^https://", var.proxmox_endpoint))
    error_message = "Proxmox endpoint must use HTTPS protocol."
  }
}

variable "proxmox_api_token" {
  description = "Proxmox API token in format: user@realm!token-name=token-value"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[a-zA-Z0-9]+@[a-zA-Z0-9]+![a-zA-Z0-9-]+=.+$", var.proxmox_api_token))
    error_message = "API token must be in format: user@realm!token-name=token-value"
  }
}

variable "proxmox_user" {
  description = "Username for SSH connection to Proxmox host (for file uploads)"
  type        = string
  sensitive   = true
}

variable "ssh_agent_option" {
  description = "Use SSH agent for authentication to Proxmox host"
  type        = bool
  default     = true
}

variable "connection_option_insecure" {
  description = "Skip TLS certificate verification (set to false in production)"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Proxmox Infrastructure Variables
# -----------------------------------------------------------------------------

variable "proxmox_node_name" {
  description = "Name of the Proxmox node where VM will be created"
  type        = string
}

variable "pve_datastore" {
  description = "Datastore for cloud image downloads and snippets"
  type        = string
  default     = "local"
}

variable "pve_download_content_type" {
  description = "Content type for downloaded files (import for cloud images)"
  type        = string
  default     = "import"
}

# -----------------------------------------------------------------------------
# VM Identity Variables
# -----------------------------------------------------------------------------

variable "vm_id" {
  description = "Unique VM ID in Proxmox (100-999999999)"
  type        = number

  validation {
    condition     = var.vm_id >= 100 && var.vm_id <= 999999999
    error_message = "VM ID must be between 100 and 999999999."
  }
}

variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
  default     = "terraform-ubuntu-vm"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.vm_name))
    error_message = "VM name can only contain alphanumeric characters and hyphens."
  }
}

variable "vm_tags" {
  description = "Tags for VM organization and filtering"
  type        = list(string)
  default     = ["terraform", "ubuntu"]
}

variable "vm_description" {
  description = "Description of the virtual machine"
  type        = string
  default     = "Ubuntu Server VM managed by OpenTofu/Terraform"
}

# -----------------------------------------------------------------------------
# VM Lifecycle Variables
# -----------------------------------------------------------------------------

variable "qemu_agent_option" {
  description = "Enable QEMU Guest Agent for VM management"
  type        = bool
  default     = true
}

variable "vm_stop_on_destroy_option" {
  description = "Gracefully stop VM before destroying"
  type        = bool
  default     = true
}

variable "vm_startup_order" {
  description = "Boot order priority (lower = earlier)"
  type        = string
  default     = "3"
}

variable "vm_startup_up_delay" {
  description = "Seconds to wait after starting this VM before starting the next"
  type        = string
  default     = "60"
}

variable "vm_startup_down_delay" {
  description = "Seconds to wait after stopping this VM before stopping the next"
  type        = string
  default     = "60"
}

# -----------------------------------------------------------------------------
# VM Hardware Variables
# -----------------------------------------------------------------------------

variable "vm_cpu_core" {
  description = "Number of CPU cores allocated to the VM"
  type        = number
  default     = 2

  validation {
    condition     = var.vm_cpu_core >= 1 && var.vm_cpu_core <= 128
    error_message = "CPU cores must be between 1 and 128."
  }
}

variable "vm_cpu_type" {
  description = "CPU type (host = best performance, x86-64-v2-AES = portable)"
  type        = string
  default     = "x86-64-v2-AES"
}

variable "vm_machine_type" {
  description = "Machine type (q35 recommended for modern guests)"
  type        = string
  default     = "q35"
}

variable "vm_memory_dedicated" {
  description = "Dedicated memory in MB"
  type        = number
  default     = 2048

  validation {
    condition     = var.vm_memory_dedicated >= 512
    error_message = "Minimum memory is 512 MB."
  }
}

variable "vm_memory_floating" {
  description = "Maximum memory for ballooning in MB (0 = disabled)"
  type        = number
  default     = 2048
}

# -----------------------------------------------------------------------------
# VM Storage Variables
# -----------------------------------------------------------------------------

variable "vm_disk_datastore_id" {
  description = "Datastore ID for VM disks (e.g., local-lvm, local-zfs)"
  type        = string
  default     = "local-lvm"
}

variable "vm_disk_interface" {
  description = "Disk interface type (scsi0, virtio0, etc.)"
  type        = string
  default     = "scsi0"
}

variable "vm_boot_disk_size" {
  description = "Boot disk size in GB"
  type        = number
  default     = 15

  validation {
    condition     = var.vm_boot_disk_size >= 5
    error_message = "Boot disk must be at least 5 GB."
  }
}

# -----------------------------------------------------------------------------
# VM Network Variables
# -----------------------------------------------------------------------------

variable "vm_init_ip_config_ipv4" {
  description = "IPv4 configuration (dhcp or CIDR like 192.168.1.100/24)"
  type        = string
  default     = "dhcp"
}

variable "vm_network_device_bridge" {
  description = "Network bridge to attach VM to"
  type        = string
  default     = "vmbr0"
}

# -----------------------------------------------------------------------------
# VM OS and Security Variables
# -----------------------------------------------------------------------------

variable "vm_user_account_username" {
  description = "Username for the VM user account"
  type        = string
  default     = "ubuntu"
}

variable "vm_operating_system_type" {
  description = "OS type hint for Proxmox (l26 = Linux 2.6+)"
  type        = string
  default     = "l26"
}

variable "vm_tpm_state" {
  description = "TPM version (v2.0 recommended for modern security)"
  type        = string
  default     = "v2.0"
}

# -----------------------------------------------------------------------------
# VirtioFS Variables (Optional - for shared folders)
# Note: Requires Proxmox directory mapping configuration
# -----------------------------------------------------------------------------

variable "vm_virtiofs_mapping" {
  description = "VirtioFS directory mapping name (requires Proxmox configuration)"
  type        = string
  default     = "data_share"
}

variable "vm_virtiofs_cache" {
  description = "VirtioFS cache mode (always, auto, none)"
  type        = string
  default     = "always"
}

variable "vm_virtiofs_direct_io" {
  description = "Enable VirtioFS direct I/O"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Cloud Image Variables
# -----------------------------------------------------------------------------

variable "vm_download_img_url" {
  description = "URL to download Ubuntu cloud image"
  type        = string

  validation {
    condition     = can(regex("^https://", var.vm_download_img_url))
    error_message = "Cloud image URL must use HTTPS for security."
  }
}

variable "vm_qcow2_file_name" {
  description = "Filename for the downloaded cloud image"
  type        = string
}

# -----------------------------------------------------------------------------
# Password Generation Variables
# Note: Variable names use 'randow' (typo) for backward compatibility
# -----------------------------------------------------------------------------

variable "vm_randow_password_length" {
  description = "Length of generated random password"
  type        = number
  default     = 16

  validation {
    condition     = var.vm_randow_password_length >= 12
    error_message = "Password must be at least 12 characters for security."
  }
}

variable "vm_randow_password_special_option" {
  description = "Include special characters in password"
  type        = bool
  default     = true
}

variable "vm_randow_password_special_string" {
  description = "Allowed special characters in password"
  type        = string
  default     = "_%@"
}

# -----------------------------------------------------------------------------
# SSH Configuration Variables
# -----------------------------------------------------------------------------

variable "ssh_key_path" {
  description = "Path to SSH public key file for VM authentication"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}