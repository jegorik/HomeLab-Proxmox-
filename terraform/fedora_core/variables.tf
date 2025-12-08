# ╔════════════════════════════════════════════════════════════════════════════╗
# ║                     Fedora CoreOS VM - Variables                           ║
# ║                                                                            ║
# ║  OpenTofu variables for provisioning Fedora CoreOS VMs on Proxmox VE       ║
# ║  Fedora CoreOS uses Ignition for configuration (NOT cloud-init)            ║
# ║                                                                            ║
# ║  Author: jegorik                                                           ║
# ║  Last Updated: December 2025                                               ║
# ╚════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# PROXMOX CONNECTION VARIABLES
# ==============================================================================

variable "proxmox_api_url" {
  description = <<-EOT
    Proxmox VE API endpoint URL.
    Format: https://<ip-or-hostname>:8006
    Example: https://192.168.0.204:8006
  EOT
  type        = string

  validation {
    condition     = can(regex("^https?://", var.proxmox_api_url))
    error_message = "Proxmox API URL must start with http:// or https://"
  }
}

variable "proxmox_api_token" {
  description = <<-EOT
    Proxmox API token for authentication.
    Format: <user>@<realm>!<token_name>=<token_secret>
    Example: terraform@pam!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    
    NOTE: This token is used for VM creation operations.
    Ignition injection is handled separately via Ansible playbook
    (which uses sudo on the Proxmox host).
  EOT
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = <<-EOT
    Proxmox node name where the VM will be created.
    This is the hostname of your Proxmox server (not IP address).
    Find it in Proxmox UI: Datacenter → <node_name>
  EOT
  type        = string
  default     = "pve"
}

variable "proxmox_insecure" {
  description = <<-EOT
    Skip TLS certificate verification for Proxmox API.
    Set to true for self-signed certificates (common in home labs).
    Set to false in production with valid certificates.
  EOT
  type        = bool
  default     = true
}

variable "proxmox_ssh_private_key" {
  description = <<-EOT
    SSH private key content for Proxmox host access.
    Used by bpg/proxmox provider for disk image operations.
    
    When running via Semaphore UI, set as environment variable:
    TF_VAR_proxmox_ssh_private_key="-----BEGIN OPENSSH PRIVATE KEY-----..."
    
    When empty, falls back to SSH agent (for local development).
    The key must correspond to the 'ansible' user on Proxmox host.
  EOT
  type        = string
  sensitive   = true
  default     = ""
}

variable "proxmox_ssh_username" {
  description = <<-EOT
    SSH username for Proxmox host access.
    Used by bpg/proxmox provider for disk image upload operations.
    Typically 'ansible' user with sudo privileges (since root login is disabled).
  EOT
  type        = string
  default     = "ansible"
}

# ==============================================================================
# VM IDENTIFICATION & BASIC SETTINGS
# ==============================================================================

variable "vm_id" {
  description = <<-EOT
    Proxmox VM ID (VMID). Must be unique across the cluster.
    Range: 100-999999999
    Set to 0 or null for auto-assignment by Proxmox.
  EOT
  type        = number
  default     = null

  validation {
    condition     = var.vm_id == null || (var.vm_id >= 100 && var.vm_id <= 999999999)
    error_message = "VM ID must be between 100 and 999999999, or null for auto-assignment."
  }
}

variable "vm_name" {
  description = <<-EOT
    VM hostname and Proxmox display name.
    Used for both the Proxmox VM name and the OS hostname.
    Should be a valid hostname (lowercase letters, numbers, hyphens).
  EOT
  type        = string
  default     = "fcos-vm"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,62}[a-z0-9]?$", var.vm_name))
    error_message = "VM name must be a valid hostname (lowercase letters, numbers, hyphens, max 63 chars)."
  }
}

variable "vm_description" {
  description = <<-EOT
    VM description displayed in Proxmox UI.
    Supports HTML for formatted notes.
  EOT
  type        = string
  default     = "Fedora CoreOS VM - Managed by OpenTofu"
}

variable "vm_tags" {
  description = <<-EOT
    Tags for the VM displayed in Proxmox UI.
    Useful for organization and filtering.
    Tags are converted to lowercase automatically.
  EOT
  type        = list(string)
  default     = ["fedora-coreos", "opentofu", "container-host"]
}

# ==============================================================================
# FEDORA COREOS IMAGE CONFIGURATION
# ==============================================================================

variable "fcos_stream" {
  description = <<-EOT
    Fedora CoreOS update stream.
    - stable: Production-ready, thoroughly tested (recommended)
    - testing: Pre-release testing, updated more frequently
    - next: Latest features, may be less stable
  EOT
  type        = string
  default     = "stable"

  validation {
    condition     = contains(["stable", "testing", "next"], var.fcos_stream)
    error_message = "FCOS stream must be 'stable', 'testing', or 'next'."
  }
}

variable "fcos_version" {
  description = <<-EOT
    Fedora CoreOS version string (e.g., "43.20251110.3.1").
    Used to construct the image filename.
    Check releases at: https://fedoraproject.org/coreos/download
  EOT
  type        = string
  default     = "43.20251110.3.1"
}

variable "fcos_image_filename" {
  description = <<-EOT
    Fedora CoreOS QCOW2 image filename.
    If empty, will be constructed from fcos_version.
    Expected format: fedora-coreos-<version>-proxmoxve.x86_64.qcow2
  EOT
  type        = string
  default     = ""
}

variable "fcos_image_local_path" {
  description = <<-EOT
    Local path where FCOS image is already downloaded on Proxmox host.
    If the image exists at this path, it will be used directly.
    If not found, the image will be downloaded from the official source.
    Example: /var/lib/vz/import
  EOT
  type        = string
  default     = "/var/lib/vz/import"
}

variable "fcos_image_download_url" {
  description = <<-EOT
    URL to download Fedora CoreOS QCOW2 image if not found locally.
    If empty, will be constructed from stream and version.
    Leave empty to use official Fedora mirrors.
    
    NOTE: Official FCOS images are compressed (.qcow2.xz).
    For pre-downloaded/decompressed images, use fcos_existing_file_id.
  EOT
  type        = string
  default     = ""
}

variable "fcos_existing_file_id" {
  description = <<-EOT
    Use an existing image already present in Proxmox storage.
    Format: <storage>:<content_type>/<filename>
    Example: "local:iso/fedora-coreos-43.20251110.3.1-proxmoxve.x86_64.qcow2"
    
    If set, skips downloading and uses this file directly.
    This is useful when:
    - Image was pre-downloaded and decompressed manually
    - Using a custom/modified image
    - Avoiding repeated downloads
    
    NOTE: The image must already exist in the specified storage.
  EOT
  type        = string
  default     = ""
}

variable "proxmox_iso_storage" {
  description = <<-EOT
    Proxmox storage ID for storing the FCOS image.
    This storage must support ISO/images (typically 'local' or 'local-lvm').
    The image will be uploaded here for VM disk creation.
  EOT
  type        = string
  default     = "local"
}

# ==============================================================================
# VM HARDWARE RESOURCES
# ==============================================================================

variable "vm_cpu_cores" {
  description = <<-EOT
    Number of CPU cores allocated to the VM.
    Fedora CoreOS minimum: 2 cores recommended for container workloads.
  EOT
  type        = number
  default     = 2

  validation {
    condition     = var.vm_cpu_cores >= 1 && var.vm_cpu_cores <= 128
    error_message = "CPU cores must be between 1 and 128."
  }
}

variable "vm_cpu_sockets" {
  description = <<-EOT
    Number of CPU sockets for the VM.
    Total vCPUs = sockets × cores. Usually 1 socket is sufficient.
  EOT
  type        = number
  default     = 1

  validation {
    condition     = var.vm_cpu_sockets >= 1 && var.vm_cpu_sockets <= 4
    error_message = "CPU sockets must be between 1 and 4."
  }
}

variable "vm_cpu_type" {
  description = <<-EOT
    CPU type emulated by QEMU.
    - host: Best performance, exposes host CPU features (recommended)
    - x86-64-v2-AES: Good compatibility with modern features
    - kvm64: Maximum compatibility, basic features
  EOT
  type        = string
  default     = "host"
}

variable "vm_memory" {
  description = <<-EOT
    RAM allocated to the VM in megabytes (MB).
    Fedora CoreOS minimum: 2048 MB (2 GB)
    Recommended for containers: 4096 MB (4 GB) or more
  EOT
  type        = number
  default     = 4096

  validation {
    condition     = var.vm_memory >= 1024 && var.vm_memory <= 1048576
    error_message = "Memory must be between 1024 MB and 1048576 MB (1 TB)."
  }
}

variable "vm_balloon_memory" {
  description = <<-EOT
    Minimum memory for balloon device in MB.
    Set to 0 to disable memory ballooning (recommended for containers).
    Memory ballooning can cause issues with container workloads.
  EOT
  type        = number
  default     = 0
}

# ==============================================================================
# VM STORAGE CONFIGURATION
# ==============================================================================

variable "vm_disk_size" {
  description = <<-EOT
    Primary disk size for the VM.
    Format: number with unit (G for GB, M for MB, T for TB).
    Fedora CoreOS minimum: 10G, recommended: 32G+ for container images.
  EOT
  type        = string
  default     = "32G"

  validation {
    condition     = can(regex("^[0-9]+[GMT]$", var.vm_disk_size))
    error_message = "Disk size must be a number followed by G, M, or T (e.g., '32G', '100G')."
  }
}

variable "vm_storage_pool" {
  description = <<-EOT
    Proxmox storage pool for VM disks.
    Common options:
    - local-lvm: LVM thin provisioning (default on most installations)
    - local-zfs: ZFS storage (better performance, snapshots)
    - <nfs-storage>: Network storage for migration support
  EOT
  type        = string
  default     = "local-lvm"
}

variable "vm_disk_interface" {
  description = <<-EOT
    Disk bus/interface type.
    - virtio: Best performance (requires VirtIO drivers)
    - scsi: Good performance with VirtIO SCSI controller
    - sata: Maximum compatibility, lower performance
    Fedora CoreOS has VirtIO drivers built-in, use virtio or scsi.
  EOT
  type        = string
  default     = "virtio0"

  validation {
    condition     = can(regex("^(virtio|scsi|sata|ide)[0-9]+$", var.vm_disk_interface))
    error_message = "Disk interface must be virtio0, scsi0, sata0, etc."
  }
}

variable "vm_disk_discard" {
  description = <<-EOT
    Enable TRIM/discard support for SSD storage.
    Recommended for SSD-backed storage to maintain performance.
  EOT
  type        = bool
  default     = true
}

variable "vm_disk_ssd_emulation" {
  description = <<-EOT
    Enable SSD emulation for the disk.
    Enables SSD-specific optimizations in the guest OS.
    Enable if your storage is SSD-backed.
  EOT
  type        = bool
  default     = true
}

variable "vm_disk_iothread" {
  description = <<-EOT
    Enable IO thread for the disk (requires VirtIO SCSI controller).
    Improves disk I/O performance by dedicating a thread to disk operations.
  EOT
  type        = bool
  default     = true
}

# ==============================================================================
# VM NETWORK CONFIGURATION
# ==============================================================================

variable "vm_network_bridge" {
  description = <<-EOT
    Proxmox network bridge for the VM.
    Default 'vmbr0' is typically the main bridge connected to your LAN.
    Check your Proxmox network configuration for available bridges.
  EOT
  type        = string
  default     = "vmbr0"
}

variable "vm_network_model" {
  description = <<-EOT
    Network interface model.
    - virtio: Best performance (recommended, drivers included in FCOS)
    - e1000: Intel emulation, good compatibility
    - vmxnet3: VMware compatibility
  EOT
  type        = string
  default     = "virtio"

  validation {
    condition     = contains(["virtio", "e1000", "e1000e", "vmxnet3", "rtl8139"], var.vm_network_model)
    error_message = "Network model must be virtio, e1000, e1000e, vmxnet3, or rtl8139."
  }
}

variable "vm_network_vlan" {
  description = <<-EOT
    VLAN tag for the network interface.
    Set to null or -1 for no VLAN tagging (default).
    Range: 1-4094 for valid VLAN IDs.
  EOT
  type        = number
  default     = null

  validation {
    condition     = var.vm_network_vlan == null || (var.vm_network_vlan >= 1 && var.vm_network_vlan <= 4094)
    error_message = "VLAN ID must be between 1 and 4094, or null for no VLAN."
  }
}

variable "vm_network_firewall" {
  description = <<-EOT
    Enable Proxmox firewall for the network interface.
    Requires firewall rules to be configured in Proxmox.
  EOT
  type        = bool
  default     = false
}

variable "vm_ip_address" {
  description = <<-EOT
    Static IPv4 address for the VM in CIDR notation.
    If empty, DHCP will be used.
    Example: "192.168.0.50/24"
  EOT
  type        = string
  default     = ""

  validation {
    condition     = var.vm_ip_address == "" || can(cidrnetmask(var.vm_ip_address))
    error_message = "IP address must be in CIDR notation (e.g., '192.168.0.50/24') or empty for DHCP."
  }
}

variable "vm_gateway" {
  description = <<-EOT
    Default gateway IP address for static network configuration.
    Required if vm_ip_address is set.
    Example: "192.168.0.1"
  EOT
  type        = string
  default     = ""

  validation {
    condition     = var.vm_gateway == "" || can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", var.vm_gateway))
    error_message = "Gateway must be a valid IPv4 address or empty."
  }
}

variable "vm_dns_servers" {
  description = <<-EOT
    DNS server IP addresses for the VM.
    Used for static network configuration.
    Example: ["8.8.8.8", "8.8.4.4"]
  EOT
  type        = list(string)
  default     = ["8.8.8.8", "1.1.1.1"]

  validation {
    condition     = alltrue([for dns in var.vm_dns_servers : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", dns))])
    error_message = "All DNS servers must be valid IPv4 addresses."
  }
}

# ==============================================================================
# SSH & USER CONFIGURATION (for Ignition/Butane)
# ==============================================================================

variable "ssh_user" {
  description = <<-EOT
    Username for SSH access to the VM.
    This user will be created via Ignition with sudo privileges.
    Fedora CoreOS convention: 'core' is the default user.
  EOT
  type        = string
  default     = "core"

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]{0,31}$", var.ssh_user))
    error_message = "Username must be a valid Linux username (lowercase, start with letter or underscore)."
  }
}

variable "ssh_public_key" {
  description = <<-EOT
    SSH public key for passwordless authentication.
    This is the ONLY way to access Fedora CoreOS (no password auth).
    Format: ssh-rsa AAAA... user@host or ssh-ed25519 AAAA... user@host
  EOT
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^ssh-(rsa|ed25519|ecdsa)", var.ssh_public_key))
    error_message = "SSH public key must start with ssh-rsa, ssh-ed25519, or ssh-ecdsa."
  }
}

variable "ssh_public_keys_additional" {
  description = <<-EOT
    Additional SSH public keys for the user.
    Useful for adding multiple authorized keys for team access.
  EOT
  type        = list(string)
  default     = []
}

# ==============================================================================
# IGNITION / BUTANE CONFIGURATION
# ==============================================================================

variable "butane_template_path" {
  description = <<-EOT
    Path to the Butane YAML template file.
    Butane is transpiled to Ignition JSON for CoreOS configuration.
    Relative to the module directory.
  EOT
  type        = string
  default     = "butane/fcos-vm.yaml.tftpl"
}

variable "ignition_custom_config" {
  description = <<-EOT
    Additional Ignition configuration to merge.
    Must be valid Ignition JSON (not Butane YAML).
    Used for advanced configurations not covered by the template.
  EOT
  type        = string
  default     = ""
}

variable "enable_qemu_guest_agent" {
  description = <<-EOT
    Install and enable QEMU Guest Agent via Ignition.
    Required for:
    - Proper VM shutdown from Proxmox
    - IP address reporting in Proxmox UI
    - Filesystem freeze for snapshots
    
    Note: Installs via rpm-ostree and requires a reboot.
  EOT
  type        = bool
  default     = true
}

variable "timezone" {
  description = <<-EOT
    Timezone for the VM.
    Format: Region/City (e.g., "Europe/Kiev", "America/New_York", "UTC")
    See: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
  EOT
  type        = string
  default     = "UTC"
}

# ==============================================================================
# VM BEHAVIOR & LIFECYCLE
# ==============================================================================

variable "vm_on_boot" {
  description = <<-EOT
    Start VM automatically when Proxmox host boots.
    Useful for critical infrastructure VMs.
  EOT
  type        = bool
  default     = true
}

variable "vm_started" {
  description = <<-EOT
    Start the VM immediately after creation.
    Set to false if you need to make changes before first boot.
  EOT
  type        = bool
  default     = true
}

variable "vm_boot_order" {
  description = <<-EOT
    Boot device order for the VM.
    Format: comma-separated list (e.g., "scsi0;net0")
    Common values: scsi0, virtio0, ide0, net0
  EOT
  type        = string
  default     = "virtio0"
}

variable "vm_startup_order" {
  description = <<-EOT
    Startup/shutdown order for automatic start.
    Lower numbers start first, shutdown last.
    Format: order=N,up=N,down=N
    Example: "order=1,up=30,down=60"
  EOT
  type        = string
  default     = ""
}

variable "vm_protection" {
  description = <<-EOT
    Enable VM protection against accidental deletion.
    When enabled, VM cannot be removed without first disabling protection.
  EOT
  type        = bool
  default     = false
}

variable "vm_tablet_device" {
  description = <<-EOT
    Enable USB tablet device for mouse pointer.
    Improves mouse behavior in VNC/SPICE console.
    Can be disabled for server workloads to save resources.
  EOT
  type        = bool
  default     = false
}

variable "vm_keyboard_layout" {
  description = <<-EOT
    Keyboard layout for the VM console.
    Common values: en-us, de, fr, uk, ru
  EOT
  type        = string
  default     = "en-us"
}

# ==============================================================================
# ADVANCED VM OPTIONS
# ==============================================================================

variable "vm_machine_type" {
  description = <<-EOT
    QEMU machine type.
    - q35: Modern chipset with PCIe support (recommended)
    - i440fx: Legacy chipset, better compatibility
  EOT
  type        = string
  default     = "q35"

  validation {
    condition     = contains(["q35", "i440fx"], var.vm_machine_type)
    error_message = "Machine type must be 'q35' or 'i440fx'."
  }
}

variable "vm_bios" {
  description = <<-EOT
    BIOS type for the VM.
    - seabios: Traditional BIOS (default)
    - ovmf: UEFI firmware (required for Secure Boot)
    Fedora CoreOS supports both, UEFI recommended for modern setups.
  EOT
  type        = string
  default     = "seabios"

  validation {
    condition     = contains(["seabios", "ovmf"], var.vm_bios)
    error_message = "BIOS must be 'seabios' or 'ovmf'."
  }
}

variable "vm_scsi_hardware" {
  description = <<-EOT
    SCSI controller type.
    - virtio-scsi-single: Best performance with IO threads
    - virtio-scsi-pci: Good performance, multiple devices
    - lsi: LSI Logic compatibility
  EOT
  type        = string
  default     = "virtio-scsi-single"
}

variable "vm_numa" {
  description = <<-EOT
    Enable NUMA (Non-Uniform Memory Access) for the VM.
    Improves performance on multi-socket systems.
  EOT
  type        = bool
  default     = false
}

variable "vm_hotplug" {
  description = <<-EOT
    Hotplug capabilities for the VM.
    Allows adding devices without shutdown.
    Format: comma-separated list (disk,network,usb,memory,cpu)
  EOT
  type        = string
  default     = "disk,network,usb"
}

# ==============================================================================
# RESOURCE POOL & PLACEMENT
# ==============================================================================

variable "proxmox_pool" {
  description = <<-EOT
    Proxmox resource pool to add the VM to.
    Pools are used for organizing VMs and setting permissions.
    Leave empty for no pool assignment.
  EOT
  type        = string
  default     = ""
}

# ==============================================================================
# DEPLOYMENT CONTROL
# ==============================================================================

variable "create_vm" {
  description = <<-EOT
    Whether to create the VM.
    Set to false to plan without creating resources.
    Useful for testing configurations.
  EOT
  type        = bool
  default     = true
}

variable "provision_timeout" {
  description = <<-EOT
    Timeout for VM provisioning operations in seconds.
    Increase for slow storage or large images.
  EOT
  type        = number
  default     = 600

  validation {
    condition     = var.provision_timeout >= 60 && var.provision_timeout <= 3600
    error_message = "Provision timeout must be between 60 and 3600 seconds."
  }
}

# ==============================================================================
# IGNITION OUTPUT CONFIGURATION (FOR ANSIBLE INTEGRATION)
# ==============================================================================

variable "ignition_output_path" {
  description = <<-EOT
    Directory path where the generated Ignition JSON file will be saved.
    This file is used by the Ansible playbook to apply Ignition config to the VM.
    
    The file will be named: ignition-<vm_name>.json
    
    Workflow:
    1. OpenTofu creates VM (stopped) and generates ignition JSON file
    2. Ansible playbook reads this file and applies it via 'qm set -args'
    3. Ansible starts the VM
    
    Relative paths are relative to the OpenTofu working directory.
  EOT
  type        = string
  default     = "./output"
}
