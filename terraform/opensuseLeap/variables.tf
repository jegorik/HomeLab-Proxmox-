# =============================================================================
# OpenTofu/Terraform Variables for OpenSUSE Leap 16 VM
# =============================================================================
# This file defines all configurable variables for the VM infrastructure.
# Best practices:
# - Use terraform.tfvars or environment variables for sensitive values
# - Set reasonable defaults for non-sensitive configuration
# - Add validation rules where appropriate
# - Group related variables with clear comments
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
  default     = "pve"
}

# -----------------------------------------------------------------------------
# VM Identity Variables
# -----------------------------------------------------------------------------

variable "vm_id" {
  description = "Unique VM ID in Proxmox (100-999999999)"
  type        = number
  default     = 100

  validation {
    condition     = var.vm_id >= 100 && var.vm_id <= 999999999
    error_message = "VM ID must be between 100 and 999999999."
  }
}

variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
  default     = "opensuseLeap16"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.vm_name))
    error_message = "VM name can only contain alphanumeric characters and hyphens."
  }
}

variable "vm_tags" {
  description = "Tags for VM organization and filtering"
  type        = list(string)
  default     = ["tofu-managed", "workstation"]
}

variable "vm_description" {
  description = "Description of the virtual machine"
  type        = string
  default     = "OpenSUSE Leap 16 workstation with GPU passthrough, managed by OpenTofu"
}

# -----------------------------------------------------------------------------
# VM Lifecycle Variables
# -----------------------------------------------------------------------------

variable "vm_on_boot" {
  description = "Start VM automatically when Proxmox host boots"
  type        = bool
  default     = true
}

variable "vm_started" {
  description = "Initial state of the VM (true = running, false = stopped)"
  type        = bool
  default     = true
}

variable "vm_stop_on_destroy" {
  description = "Gracefully stop VM before destroying (false = forced shutdown)"
  type        = bool
  default     = false
}

variable "vm_protection" {
  description = "Protect VM from accidental deletion"
  type        = bool
  default     = false
}

variable "vm_startup_order" {
  description = "Boot order priority (lower = earlier)"
  type        = number
  default     = 1
}

variable "vm_startup_up_delay" {
  description = "Seconds to wait after starting this VM before starting the next"
  type        = number
  default     = 30
}

variable "vm_startup_down_delay" {
  description = "Seconds to wait after stopping this VM before stopping the next"
  type        = number
  default     = 30
}

# -----------------------------------------------------------------------------
# QEMU Guest Agent Configuration
# -----------------------------------------------------------------------------

variable "qemu_agent_enabled" {
  description = "Enable QEMU Guest Agent for enhanced VM management"
  type        = bool
  default     = true
}

variable "qemu_agent_timeout" {
  description = "Timeout for QEMU Guest Agent operations"
  type        = string
  default     = "15m"
}

variable "qemu_agent_trim" {
  description = "Enable fstrim support via QEMU Guest Agent"
  type        = bool
  default     = false
}

variable "qemu_agent_type" {
  description = "Type of QEMU Guest Agent"
  type        = string
  default     = "virtio"
}

# -----------------------------------------------------------------------------
# BIOS and Machine Configuration
# -----------------------------------------------------------------------------

variable "vm_bios" {
  description = "BIOS type (ovmf = UEFI, seabios = Legacy BIOS)"
  type        = string
  default     = "ovmf"

  validation {
    condition     = contains(["ovmf", "seabios"], var.vm_bios)
    error_message = "BIOS must be either 'ovmf' or 'seabios'."
  }
}

variable "vm_machine_type" {
  description = "Machine type (q35 recommended for modern guests, pc for older systems)"
  type        = string
  default     = "q35"
}

variable "vm_boot_order" {
  description = "Boot device order (e.g., scsi0, ide2, net0)"
  type        = list(string)
  default     = ["scsi0", "ide2", "net0"]
}

# -----------------------------------------------------------------------------
# CPU Configuration Variables
# -----------------------------------------------------------------------------

variable "vm_cpu_cores" {
  description = "Number of CPU cores allocated to the VM"
  type        = number
  default     = 2

  validation {
    condition     = var.vm_cpu_cores >= 1 && var.vm_cpu_cores <= 128
    error_message = "CPU cores must be between 1 and 128."
  }
}

variable "vm_cpu_sockets" {
  description = "Number of CPU sockets"
  type        = number
  default     = 1

  validation {
    condition     = var.vm_cpu_sockets >= 1 && var.vm_cpu_sockets <= 4
    error_message = "CPU sockets must be between 1 and 4."
  }
}

variable "vm_cpu_type" {
  description = "CPU type (host = best performance, x86-64-v2-AES = portable)"
  type        = string
  default     = "x86-64-v2-AES"
}

variable "vm_cpu_architecture" {
  description = "CPU architecture (leave empty for default)"
  type        = string
  default     = ""
}

variable "vm_cpu_hotplugged" {
  description = "Number of hotplugged vCPUs"
  type        = number
  default     = 0
}

variable "vm_cpu_limit" {
  description = "CPU limit (0 = unlimited)"
  type        = number
  default     = 0
}

variable "vm_cpu_units" {
  description = "CPU weight for fair scheduler (1-262144)"
  type        = number
  default     = 1024

  validation {
    condition     = var.vm_cpu_units >= 1 && var.vm_cpu_units <= 262144
    error_message = "CPU units must be between 1 and 262144."
  }
}

variable "vm_cpu_numa" {
  description = "Enable NUMA support"
  type        = bool
  default     = false
}

variable "vm_kvm_arguments" {
  description = "Custom KVM arguments for CPU features and Hyper-V enlightenments"
  type        = string
  default     = "-cpu 'host,hv_ipi,hv_relaxed,hv_reset,hv_runtime,hv_spinlocks=0x1fff,hv_stimer,hv_synic,hv_time,hv_vapic,hv_vpindex,kvm=off,+kvm_pv_eoi,+kvm_pv_unhalt'"
}

# -----------------------------------------------------------------------------
# Memory Configuration Variables
# -----------------------------------------------------------------------------

variable "vm_memory_dedicated" {
  description = "Dedicated memory in MB"
  type        = number
  default     = 12288

  validation {
    condition     = var.vm_memory_dedicated >= 512
    error_message = "Minimum memory is 512 MB."
  }
}

variable "vm_memory_floating" {
  description = "Maximum memory for ballooning in MB"
  type        = number
  default     = 16384
}

variable "vm_memory_shared" {
  description = "Shared memory in MB (for inter-VM communication)"
  type        = number
  default     = 0
}

variable "vm_memory_keep_hugepages" {
  description = "Keep hugepages allocated after VM shutdown"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# EFI Disk Configuration Variables
# -----------------------------------------------------------------------------

variable "vm_efi_disk_datastore_id" {
  description = "Datastore for EFI disk"
  type        = string
  default     = "local-zfs"
}

variable "vm_efi_disk_file_format" {
  description = "File format for EFI disk (raw or qcow2)"
  type        = string
  default     = "raw"
}

variable "vm_efi_disk_type" {
  description = "EFI disk type (2m or 4m)"
  type        = string
  default     = "4m"
}

variable "vm_efi_disk_pre_enrolled_keys" {
  description = "Use pre-enrolled keys for Secure Boot"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Main Disk Configuration Variables
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

variable "vm_disk_size" {
  description = "Boot disk size in GB"
  type        = number
  default     = 50

  validation {
    condition     = var.vm_disk_size >= 5
    error_message = "Boot disk must be at least 5 GB."
  }
}

variable "vm_disk_file_format" {
  description = "Disk file format (raw or qcow2)"
  type        = string
  default     = "raw"
}

variable "vm_disk_aio" {
  description = "Asynchronous IO mode (io_uring, native, threads)"
  type        = string
  default     = "io_uring"
}

variable "vm_disk_cache" {
  description = "Disk cache mode (none, writeback, writethrough, directsync, unsafe)"
  type        = string
  default     = "writeback"
}

variable "vm_disk_discard" {
  description = "Enable discard/TRIM support (on or ignore)"
  type        = string
  default     = "on"
}

variable "vm_disk_iothread" {
  description = "Enable dedicated IO thread for this disk"
  type        = bool
  default     = true
}

variable "vm_disk_ssd" {
  description = "Emulate SSD (enables TRIM in guest)"
  type        = bool
  default     = false
}

variable "vm_disk_backup" {
  description = "Include disk in backups"
  type        = bool
  default     = true
}

variable "vm_disk_replicate" {
  description = "Enable disk replication"
  type        = bool
  default     = true
}

variable "vm_scsi_hardware" {
  description = "SCSI controller type (virtio-scsi-single, virtio-scsi-pci, lsi)"
  type        = string
  default     = "virtio-scsi-single"
}

# -----------------------------------------------------------------------------
# Network Configuration Variables
# -----------------------------------------------------------------------------

variable "vm_network_bridge" {
  description = "Network bridge to attach VM to"
  type        = string
  default     = "vmbr0"
}

variable "vm_network_mac_address" {
  description = "MAC address for the network interface (leave empty for auto-generated)"
  type        = string
  default     = "AC:14:11:ED:28:55"
}

variable "vm_network_model" {
  description = "Network card model (virtio, e1000, rtl8139)"
  type        = string
  default     = "virtio"
}

variable "vm_network_queues" {
  description = "Number of packet queues (0 = auto, max = number of CPU cores)"
  type        = number
  default     = 2
}

variable "vm_network_enabled" {
  description = "Enable network interface"
  type        = bool
  default     = true
}

variable "vm_network_firewall" {
  description = "Enable Proxmox firewall for this interface"
  type        = bool
  default     = false
}

variable "vm_network_disconnected" {
  description = "Start with network cable disconnected"
  type        = bool
  default     = false
}

variable "vm_network_mtu" {
  description = "MTU size (0 = inherited from bridge)"
  type        = number
  default     = 0
}

variable "vm_network_rate_limit" {
  description = "Rate limit in MB/s (0 = unlimited)"
  type        = number
  default     = 0
}

# -----------------------------------------------------------------------------
# Operating System Configuration
# -----------------------------------------------------------------------------

variable "vm_os_type" {
  description = "OS type hint for Proxmox (l26 = Linux 2.6+, l24 = Linux 2.4, win10 = Windows 10/11)"
  type        = string
  default     = "l26"
}

# -----------------------------------------------------------------------------
# VGA and Display Configuration
# -----------------------------------------------------------------------------

variable "vm_vga_type" {
  description = "VGA type (std, cirrus, vmware, virtio, none)"
  type        = string
  default     = "none"
}

variable "vm_vga_memory" {
  description = "VGA memory in MB"
  type        = number
  default     = 16
}

variable "vm_tablet_device" {
  description = "Enable tablet device for better mouse handling"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# SMBIOS Configuration
# -----------------------------------------------------------------------------

variable "vm_smbios_manufacturer" {
  description = "SMBIOS manufacturer string"
  type        = string
  default     = "American Megatrends Inc."
}

variable "vm_smbios_serial" {
  description = "SMBIOS serial number"
  type        = string
  default     = "25973654482254"
}

variable "vm_smbios_uuid" {
  description = "SMBIOS UUID"
  type        = string
  default     = "000000-0000-0000-0000-00000000000"
}

variable "vm_smbios_version" {
  description = "SMBIOS version string"
  type        = string
  default     = "5321"
}

# -----------------------------------------------------------------------------
# PCI Passthrough Configuration (GPU and Audio)
# -----------------------------------------------------------------------------

# Primary GPU (hostpci0)
variable "vm_hostpci0_id" {
  description = "PCI device ID for GPU passthrough (e.g., 0000:0b:00)"
  type        = string
  default     = "0000:0b:00"
}

variable "vm_hostpci0_pcie" {
  description = "Enable PCIe passthrough for GPU"
  type        = bool
  default     = true
}

variable "vm_hostpci0_rombar" {
  description = "Enable ROM BAR for GPU"
  type        = bool
  default     = true
}

variable "vm_hostpci0_xvga" {
  description = "Enable primary VGA for GPU passthrough"
  type        = bool
  default     = true
}

# Audio Device (hostpci4)
variable "vm_hostpci4_id" {
  description = "PCI device ID for GPU audio passthrough (e.g., 0000:0c:00.1)"
  type        = string
  default     = "0000:0c:00.1"
}

variable "vm_hostpci4_pcie" {
  description = "Enable PCIe passthrough for audio device"
  type        = bool
  default     = false
}

variable "vm_hostpci4_rombar" {
  description = "Enable ROM BAR for audio device"
  type        = bool
  default     = true
}

variable "vm_hostpci4_xvga" {
  description = "Enable VGA for audio device (usually false)"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# USB Device Passthrough Configuration
# -----------------------------------------------------------------------------

variable "vm_usb_device_1_host" {
  description = "USB device 1 host identifier (vendor:product or bus-port)"
  type        = string
  default     = "212e:1534"
}

variable "vm_usb_device_1_usb3" {
  description = "Enable USB 3.0 for device 1"
  type        = bool
  default     = false
}

variable "vm_usb_device_2_host" {
  description = "USB device 2 host identifier (vendor:product or bus-port)"
  type        = string
  default     = "1-4"
}

variable "vm_usb_device_2_usb3" {
  description = "Enable USB 3.0 for device 2"
  type        = bool
  default     = false
}

variable "vm_usb_device_3_host" {
  description = "USB device 3 host identifier (vendor:product or bus-port)"
  type        = string
  default     = "4-2.4"
}

variable "vm_usb_device_3_usb3" {
  description = "Enable USB 3.0 for device 3"
  type        = bool
  default     = false
}

variable "vm_usb_device_4_host" {
  description = "USB device 4 host identifier (vendor:product or bus-port)"
  type        = string
  default     = "046d:c328"
}

variable "vm_usb_device_4_usb3" {
  description = "Enable USB 3.0 for device 4"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Timeout Configuration
# -----------------------------------------------------------------------------

variable "vm_timeout_create" {
  description = "Timeout for VM creation in seconds"
  type        = number
  default     = 1800
}

variable "vm_timeout_clone" {
  description = "Timeout for VM cloning in seconds"
  type        = number
  default     = 1800
}

variable "vm_timeout_start_vm" {
  description = "Timeout for starting VM in seconds"
  type        = number
  default     = 1800
}

variable "vm_timeout_shutdown_vm" {
  description = "Timeout for graceful VM shutdown in seconds"
  type        = number
  default     = 1800
}

variable "vm_timeout_stop_vm" {
  description = "Timeout for forceful VM stop in seconds"
  type        = number
  default     = 300
}

variable "vm_timeout_reboot" {
  description = "Timeout for VM reboot in seconds"
  type        = number
  default     = 1800
}

variable "vm_timeout_move_disk" {
  description = "Timeout for moving disk between datastores in seconds"
  type        = number
  default     = 1800
}

variable "vm_timeout_migrate" {
  description = "Timeout for VM migration in seconds"
  type        = number
  default     = 1800
}

# -----------------------------------------------------------------------------
# State file encryption Configuration
# -----------------------------------------------------------------------------

variable "passphrase" {
  # Change passphrase to be at least 16 characters long:
  description = "Passphrase for state file encryption"
  type        = string
  default     = "changeme!"
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
# AWS Configuration
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use (optional)"
  type        = string
  default     = null
}