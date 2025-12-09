# =============================================================================
# Ubuntu Server VM - Main Configuration
# =============================================================================
#
# This module provisions an Ubuntu Server VM on Proxmox VE using cloud-init
# for initial configuration. The VM is created from a cloud image with
# automatic SSH key injection and password generation.
#
# Features:
# - Cloud-init based initialization with SSH key authentication
# - Secure random password generation for backup access
# - TPM 2.0 support for enhanced security
# - QEMU Guest Agent for VM management and IP reporting
# - Q35 machine type with VirtIO drivers for optimal performance
#
# Usage:
#   tofu init -backend-config=pg.backend.conf
#   tofu plan
#   tofu apply
#
# Security Notes:
# - SSH key authentication is preferred over password
# - Passwords are stored in Terraform state - ensure remote state is encrypted
# - API tokens should be stored securely (use environment variables or vault)
#
# =============================================================================

# -----------------------------------------------------------------------------
# Ubuntu Server Virtual Machine
# -----------------------------------------------------------------------------
resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
  name        = var.vm_name
  description = var.vm_description
  tags        = var.vm_tags

  node_name = var.proxmox_node_name
  vm_id     = var.vm_id

  # QEMU Guest Agent configuration
  # Required for retrieving VM IP addresses and executing guest commands
  agent {
    enabled = var.qemu_agent_option
    timeout = "1m"
  }

  # Gracefully stop VM before destroying to prevent data corruption
  stop_on_destroy = var.vm_stop_on_destroy_option

  # Startup/shutdown behavior for cluster boot ordering
  startup {
    order      = var.vm_startup_order
    up_delay   = var.vm_startup_up_delay
    down_delay = var.vm_startup_down_delay
  }

  # CPU configuration
  cpu {
    cores = var.vm_cpu_core
    type  = var.vm_cpu_type
  }

  # Machine type (q35 recommended for modern guests with PCIe support)
  machine = var.vm_machine_type

  # Memory configuration with ballooning support
  memory {
    dedicated = var.vm_memory_dedicated
    floating  = var.vm_memory_floating
  }

  # Boot disk imported from cloud image
  disk {
    datastore_id = var.vm_disk_datastore_id
    import_from  = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = var.vm_disk_interface
    size         = var.vm_boot_disk_size
    discard      = "on"
    ssd          = true
  }

  # Cloud-init configuration for first-boot provisioning
  initialization {
    datastore_id = var.vm_disk_datastore_id

    ip_config {
      ipv4 {
        address = var.vm_init_ip_config_ipv4
      }
    }

    # User account with SSH key authentication (primary) and password (backup)
    user_account {
      keys     = [trimspace(file(var.ssh_key_path))]
      password = random_password.ubuntu_vm_password.result
      username = var.vm_user_account_username
    }
  }

  # Network interface attached to specified bridge
  network_device {
    bridge = var.vm_network_device_bridge
  }

  # Operating system type hint for Proxmox optimizations (l26 = Linux 2.6+)
  operating_system {
    type = var.vm_operating_system_type
  }

  # TPM 2.0 for secure boot and disk encryption capabilities
  tpm_state {
    datastore_id = var.vm_disk_datastore_id
    version      = var.vm_tpm_state
  }

  # Serial console for debugging and cloud-init output viewing
  serial_device {}

  # Lifecycle rules
  lifecycle {
    # Ignore changes to SSH keys after initial creation
    # This prevents forced replacement when key file changes
    ignore_changes = [
      initialization[0].user_account[0].keys,
    ]
  }
}

# -----------------------------------------------------------------------------
# Ubuntu Cloud Image Download
# -----------------------------------------------------------------------------
# Downloads the official Ubuntu cloud image for VM provisioning.
# The image is cached on the Proxmox datastore for reuse across VMs.
# -----------------------------------------------------------------------------
resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type        = var.pve_download_content_type
  datastore_id        = var.pve_datastore
  node_name           = var.proxmox_node_name
  url                 = var.vm_download_img_url
  file_name           = var.vm_qcow2_file_name
  overwrite           = false
  overwrite_unmanaged = true
}

# -----------------------------------------------------------------------------
# Random Password Generation
# -----------------------------------------------------------------------------
# Generates a secure random password for the VM user account.
# Note: Password is stored in Terraform state - ensure state encryption.
# -----------------------------------------------------------------------------
resource "random_password" "ubuntu_vm_password" {
  length           = var.vm_randow_password_length
  special          = var.vm_randow_password_special_option
  override_special = var.vm_randow_password_special_string
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
}