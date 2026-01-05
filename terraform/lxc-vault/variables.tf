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
  default     = "vault"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,62}$", var.lxc_hostname))
    error_message = "Hostname must start with letter, contain only lowercase letters, numbers, hyphens, max 63 chars."
  }
}

variable "lxc_description" {
  description = "Container description shown in Proxmox GUI"
  type        = string
  default     = "HashiCorp Vault secrets management - Managed by OpenTofu"
}

variable "lxc_tags" {
  description = "Tags for container organization in Proxmox"
  type        = list(string)
  default     = ["vault", "secrets", "tofu-managed"]
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
    error_message = "Minimum memory is 512 Mb."
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
    error_message = "Minimum disk size is 4 GB for Vault."
  }
}

variable "lxc_disk_storage" {
  description = "Storage pool for container rootfs (e.g., local-lvm, local-zfs)"
  type        = string
  default     = "local-lvm"
}

variable "lxc_startup_order" {
  description = "Startup order for container (lower numbers start first)"
  type        = number
  default     = 10
}

variable "lxc_up_delay" {
  description = "Delay in seconds before starting this container after the previous one"
  type        = number
  default     = 10
}

variable "lxc_down_delay" {
  description = "Delay in seconds before stopping this container before the next one"
  type        = number
  default     = 10
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
  default     = "debian-13-standard_13.1-2_amd64.tar.zst"
}

variable "lxc_os_type" {
  description = "Operating system type for the container"
  type        = string
  default     = "debian"
}

# -----------------------------------------------------------------------------
# LXC Container Network Variables
# -----------------------------------------------------------------------------

variable "lxc_network_bridge" {
  description = "Network bridge to attach container to"
  type        = string
  default     = "vmbr0"
}

variable "lxc_network_interface_name" {
  description = "Name of the network interface inside the container"
  type        = string
  default     = "eth0"
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

variable "password_lower_chars_count" {
  description = "Minimum number of lowercase characters in generated passwords"
  type        = number
  default     = 4
}

variable "password_upper_chars_count" {
  description = "Minimum number of uppercase characters in generated passwords"
  type        = number
  default     = 4
}

variable "password_upper_numeric_count" {
  description = "Minimum number of numeric characters in generated passwords"
  type        = number
  default     = 4
}

variable "password_upper_special_chars_count" {
  description = "Minimum number of special characters in generated passwords"
  type        = number
  default     = 4
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file for root access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

# -----------------------------------------------------------------------------
# Ansible User Configuration Variables
# -----------------------------------------------------------------------------

variable "ansible_user_enabled" {
  description = "Enable creation of dedicated Ansible user for automation"
  type        = bool
  default     = false
}

variable "ansible_user_name" {
  description = "Username for Ansible automation user"
  type        = string
  default     = "ansible"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_-]{0,31}$", var.ansible_user_name))
    error_message = "Ansible username must start with letter, contain only lowercase letters, numbers, hyphens, underscores, max 32 chars."
  }
}

variable "ansible_ssh_public_key_path" {
  description = "Path to SSH public key file for Ansible user (separate from root key recommended)"
  type        = string
  default     = "~/.ssh/ansible_rsa.pub"
}

variable "ansible_user_sudo" {
  description = "Grant Ansible user passwordless sudo access (NOPASSWD:ALL)"
  type        = bool
  default     = true
}

variable "ansible_user_sudo_commands" {
  description = "Specific sudo commands allowed for Ansible user (empty list = ALL commands if sudo enabled)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cmd in var.ansible_user_sudo_commands : can(regex("^/", cmd))
    ])
    error_message = "Sudo commands must be absolute paths (start with /)."
  }
}

variable "ansible_user_groups" {
  description = "Additional groups for Ansible user (sudo group added automatically if ansible_user_sudo=true)"
  type        = list(string)
  default     = []
}

variable "ansible_user_shell" {
  description = "Shell for Ansible user"
  type        = string
  default     = "/bin/bash"

  validation {
    condition     = contains(["/bin/bash", "/bin/sh", "/bin/zsh", "/bin/dash"], var.ansible_user_shell)
    error_message = "Shell must be one of: /bin/bash, /bin/sh, /bin/zsh, /bin/dash."
  }
}

# -----------------------------------------------------------------------------
# Vault Configuration Variables
# -----------------------------------------------------------------------------

variable "vault_port" {
  description = "Vault HTTP port"
  type        = number
  default     = 8200

  validation {
    condition     = var.vault_port >= 1024 && var.vault_port <= 65535
    error_message = "Vault port must be between 1024 and 65535."
  }
}

# -----------------------------------------------------------------------------
# Password Generation Variables
# -----------------------------------------------------------------------------

variable "password_length" {
  description = "Length of generated passwords"
  type        = number
  default     = 25

  validation {
    condition     = var.password_length >= 16
    error_message = "Password must be at least 16 characters for security."
  }
}

variable "password_special_chars" {
  description = "Special characters allowed in generated passwords"
  type        = string
  default     = "!@#$%^&*"
}

# -----------------------------------------------------------------------------
# State file encryption Configuration
# -----------------------------------------------------------------------------

variable "passphrase" {
  # Change passphrase to be at least 16 characters long:
  description = "Passphrase file location for state file encryption"
  type        = string
  default     = "~/.ssh/state_passphrase"
  sensitive   = true
}

variable "key_length" {
  description = "Key length for encryption method"
  type        = number
  default     = 32
}

variable "key_iterations" {
  description = "Number of iterations for key derivation"
  type        = number
  default     = 600000
}

variable "key_salt_length" {
  description = "Salt length for key derivation"
  type        = number
  default     = 32
}

variable "key_hash_function" {
  description = "Hash function for key derivation (sha256 or sha512)"
  type        = string
  default     = "sha512"
}

# -----------------------------------------------------------------------------
# AWS Configuration (for S3 Backend State Storage)
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for S3 backend state storage"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be in format: xx-xxxx-N (e.g., us-east-1, eu-central-1)."
  }
}