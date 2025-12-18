# =============================================================================
# OpenSUSE Leap 15.6 Virtual Machine Configuration
# =============================================================================
# This configuration manages an OpenSUSE Leap 15.6 workstation with GPU
# passthrough and advanced hardware configuration for high-performance use.
#
# Key Features:
# - GPU Passthrough (AMD/Intel/NVIDIA GPU with audio device)
# - USB Device Passthrough (peripherals and storage)
# - UEFI Boot (OVMF firmware)
# - High Performance Configuration (io_uring, writeback cache, dedicated IO)
# - QEMU Guest Agent Integration for advanced VM management
# - CPU Optimization (host passthrough, Hyper-V enlightenments)
# - State File Encryption (PBKDF2-AES-GCM)
# - Cloud-Init Automated Provisioning (user accounts, SSH keys, packages)
#
# Architecture Overview:
# ┌─────────────────────────────────────────────────────────────────┐
# │ Proxmox VE Host                                                 │
# │ ┌─────────────────────────────────────────────────────────────┐ │
# │ │ OpenSUSE Leap 15.6 VM (QEMU/KVM)                            │ │
# │ │ ├─ CPU: Host passthrough with Hyper-V enlightenments        │ │
# │ │ ├─ Memory: Dedicated allocation with ballooning support     │ │
# │ │ ├─ Disk: SCSI with io_uring async I/O                       │ │
# │ │ ├─ Network: VirtIO with multi-queue support                 │ │
# │ │ ├─ GPU: PCIe passthrough (primary VGA)                      │ │
# │ │ ├─ USB: Direct device passthrough (keyboard, mouse, etc.)   │ │
# │ │ └─ Agent: QEMU Guest Agent for advanced management          │ │
# │ └─────────────────────────────────────────────────────────────┘ │
# └─────────────────────────────────────────────────────────────────┘
#
# Usage Scenarios:
#
# Scenario 1: Create NEW VM with cloud-init provisioning
#   Set in terraform.tfvars:
#     vm_create_new = true
#     cloudinit_enabled = true
#     cloud_image_download = true
#   Run: tofu apply
#   Result: New VM created with automated user setup via cloud-init
#
# Scenario 2: Manage EXISTING VM (import into Terraform state)
#   Set in terraform.tfvars:
#     vm_create_new = false
#   Run: tofu import proxmox_virtual_environment_vm.opensuseLeap[0] <vm_id>
#   Then: tofu plan (to see current state)
#   Result: Existing VM is now managed by Terraform
#
# Scenario 3: Enable GPU/USB passthrough
#   Uncomment the hostpci and usb blocks below
#   Update device IDs in terraform.tfvars (use lspci/lsusb)
#   Run: tofu apply
#   Result: Hardware devices passed through to VM
#
# Prerequisites:
# - Proxmox VE 8.x or later
# - IOMMU enabled in BIOS and kernel (for GPU passthrough)
# - API token with appropriate permissions
# - SSH access to Proxmox host (for cloud-init file uploads)
# - OpenTofu/Terraform 1.6.0+
#
# Common Issues and Solutions:
# - Disk resize error: Ensure vm_disk_size matches or exceeds current disk size
# - Cloud-init not running: Verify snippets content type enabled on storage
# - GPU not detected: Check IOMMU groups and vfio-pci driver binding
# - SSH connection failed: Wait for cloud-init completion (check logs)
# ============================================================================

# -----------------------------------------------------------------------------
# Main VM Resource: openSUSE Leap 15.6 Workstation
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_vm" "opensuseLeap" {
  count = var.vm_create_new ? 1 : 0
  # -------------------------------------------------------------------------
  # VM Identity and Lifecycle
  # -------------------------------------------------------------------------

  vm_id       = var.vm_id
  name        = var.vm_name
  description = var.vm_description
  tags        = var.vm_tags
  node_name   = var.proxmox_node_name

  # Start VM automatically when Proxmox host boots
  on_boot = var.vm_on_boot

  # VM lifecycle options
  started             = var.vm_started
  stop_on_destroy     = var.vm_stop_on_destroy
  template            = false
  migrate             = false
  reboot              = false
  protection          = var.vm_protection
  reboot_after_update = true

  # Note: The following properties may not be supported in all provider versions:
  # delete_unreferenced_disks_on_destroy = true  # Uncomment if supported by your provider version
  # purge_on_destroy                     = true  # Uncomment if supported by your provider version

  # -------------------------------------------------------------------------
  # Lifecycle Management Configuration
  # -------------------------------------------------------------------------
  # Controls how Terraform manages VM lifecycle and state changes
  #
  # prevent_destroy: Prevents accidental deletion of the VM
  #   Use case: Production VMs that should never be deleted via Terraform
  #   Warning: Must be commented out to destroy the VM
  #
  # ignore_changes: Ignores specific attribute changes to prevent unnecessary updates
  #   Common scenarios:
  #   - MAC addresses may change on reboot or network reconfiguration
  #   - Disk size changes made manually in Proxmox GUI
  #   - Tags modified outside Terraform
  #
  # Example: Ignore all disk size changes to prevent resize errors
  #   ignore_changes = [disk[0].size]
  #
  # Example: Ignore multiple attributes
  #   ignore_changes = [network_device[0].mac_address, tags, description]

  lifecycle {
    # Uncomment to prevent VM destruction via tofu destroy
    # prevent_destroy = true

    # Uncomment to ignore specific attribute changes
    # ignore_changes = [
    #   # Ignore MAC address changes (can vary after reboot)
    #   network_device[0].mac_address,
    #   # Ignore disk size changes (prevents resize errors)
    #   disk[0].size,
    # ]
  }

  # -------------------------------------------------------------------------
  # VM Startup Configuration
  # -------------------------------------------------------------------------

  startup {
    order      = var.vm_startup_order
    up_delay   = var.vm_startup_up_delay
    down_delay = var.vm_startup_down_delay
  }

  # -------------------------------------------------------------------------
  # BIOS and Machine Type
  # -------------------------------------------------------------------------

  bios    = var.vm_bios         # OVMF for UEFI support
  machine = var.vm_machine_type # q35 for modern hardware emulation

  # -------------------------------------------------------------------------
  # Boot Configuration
  # -------------------------------------------------------------------------

  boot_order = var.vm_boot_order

  # -------------------------------------------------------------------------
  # QEMU Guest Agent
  # -------------------------------------------------------------------------
  # Enables enhanced VM management, IP detection, and graceful shutdown

  agent {
    enabled = var.qemu_agent_enabled
    timeout = var.qemu_agent_timeout
    trim    = var.qemu_agent_trim
    type    = var.qemu_agent_type
  }

  # -------------------------------------------------------------------------
  # CPU Configuration
  # -------------------------------------------------------------------------
  # High-performance CPU configuration with host passthrough for maximum performance
  #
  # CPU Type Options:
  # - "host": Maximum performance, exposes all host CPU features to guest
  #   Best for: Gaming, GPU workloads, development environments
  #   Limitation: Less portable across different CPU architectures
  #
  # - "x86-64-v2-AES": Portable baseline with AES-NI support
  #   Best for: General purpose VMs that may migrate between hosts
  #   Features: SSE4.2, AVX, AES-NI encryption
  #
  # - "kvm64": Generic x86-64 (most compatible, lowest performance)
  #   Best for: Maximum compatibility across different hardware
  #
  # Performance Tips:
  # - Set cores to match physical cores (avoid overcommit for workstation VMs)
  # - Enable NUMA if host has multiple CPU sockets
  # - Use cpu_units to prioritize CPU scheduling (higher = more priority)
  # - Consider Hyper-V enlightenments for Windows guests (via kvm_arguments)

  cpu {
    cores        = var.vm_cpu_cores
    sockets      = var.vm_cpu_sockets
    type         = var.vm_cpu_type
    architecture = var.vm_cpu_architecture
    hotplugged   = var.vm_cpu_hotplugged
    limit        = var.vm_cpu_limit
    units        = var.vm_cpu_units
    numa         = var.vm_cpu_numa
  }

  # -------------------------------------------------------------------------
  # Memory Configuration
  # -------------------------------------------------------------------------
  # Dedicated memory with ballooning support

  memory {
    dedicated      = var.vm_memory_dedicated
    floating       = var.vm_memory_floating
    shared         = var.vm_memory_shared
    keep_hugepages = var.vm_memory_keep_hugepages
  }

  # -------------------------------------------------------------------------
  # EFI Disk Configuration
  # -------------------------------------------------------------------------
  # Required for OVMF (UEFI) boot

  efi_disk {
    datastore_id      = var.vm_efi_disk_datastore_id
    file_format       = var.vm_efi_disk_file_format
    type              = var.vm_efi_disk_type
    pre_enrolled_keys = var.vm_efi_disk_pre_enrolled_keys
  }

  # -------------------------------------------------------------------------
  # Main Boot Disk Configuration
  # -------------------------------------------------------------------------
  # For new VMs with cloud-init: uses downloaded cloud image as boot disk
  # For existing VMs: creates empty disk (requires manual OS installation)
  # High-performance disk configuration with io_uring and writeback cache
  #
  # Disk Performance Options:
  #
  # AIO (Asynchronous I/O):
  # - io_uring: Latest Linux async I/O (best performance, kernel 5.1+)
  # - native: Traditional Linux AIO (good performance)
  # - threads: Thread-pool based (compatibility fallback)
  #
  # Cache Modes:
  # - writeback: Best performance, caches writes (requires safe shutdown)
  # - writethrough: Good performance, no write cache (safer)
  # - none: Direct I/O, no caching (lowest performance, highest safety)
  # - directsync: Direct I/O with sync (safest, slowest)
  #
  # Important Notes:
  # - Disk size can only be INCREASED, never decreased
  # - Use lifecycle ignore_changes for disk.size to prevent resize errors
  # - Enable discard for SSD TRIM support
  # - iothread provides dedicated thread for disk operations
  # - file_format "raw" provides better performance than "qcow2"
  #
  # KNOWN ISSUE: Disk Resize Error
  # If you see "shrinking disks is not supported" error:
  # 1. Check current disk size in Proxmox GUI
  # 2. Set vm_disk_size to current size or larger
  # 3. Or add to lifecycle block: ignore_changes = [disk[0].size]

  disk {
    datastore_id = var.vm_disk_datastore_id
    interface    = var.vm_disk_interface
    file_id      = var.vm_create_new && var.cloud_image_download ? proxmox_virtual_environment_download_file.opensuse_cloud_image[0].id : null
    size         = var.vm_disk_size
    file_format  = var.vm_disk_file_format

    # Performance optimizations
    aio      = var.vm_disk_aio
    cache    = var.vm_disk_cache
    discard  = var.vm_disk_discard
    iothread = var.vm_disk_iothread
    ssd      = var.vm_disk_ssd

    # Backup and replication
    backup    = var.vm_disk_backup
    replicate = var.vm_disk_replicate
  }

  # -------------------------------------------------------------------------
  # SCSI Controller Configuration
  # -------------------------------------------------------------------------

  scsi_hardware = var.vm_scsi_hardware

  # -------------------------------------------------------------------------
  # Network Configuration
  # -------------------------------------------------------------------------

  network_device {
    bridge       = var.vm_network_bridge
    mac_address  = var.vm_network_mac_address
    model        = var.vm_network_model
    queues       = var.vm_network_queues
    enabled      = var.vm_network_enabled
    firewall     = var.vm_network_firewall
    disconnected = var.vm_network_disconnected
    mtu          = var.vm_network_mtu
    rate_limit   = var.vm_network_rate_limit
  }

  # -------------------------------------------------------------------------
  # Cloud-Init Configuration (for new VM provisioning)
  # -------------------------------------------------------------------------
  # Configures cloud-init for automated user provisioning and system setup

  dynamic "initialization" {
    for_each = var.cloudinit_enabled && var.vm_create_new ? [1] : []

    content {
      datastore_id = var.vm_disk_datastore_id
      interface    = "ide2"

      dns {
        domain  = var.cloudinit_dns_domain
        servers = var.cloudinit_dns_servers
      }

      ip_config {
        ipv4 {
          address = var.cloudinit_use_dhcp ? "dhcp" : var.cloudinit_ipv4_address
          gateway = var.cloudinit_use_dhcp ? null : var.cloudinit_ipv4_gateway
        }
      }

      user_data_file_id = proxmox_virtual_environment_file.cloud_init_user_config[0].id
    }
  }

  # -------------------------------------------------------------------------
  # Operating System Configuration
  # -------------------------------------------------------------------------

  operating_system {
    type = var.vm_os_type
  }

  # -------------------------------------------------------------------------
  # VGA Configuration
  # -------------------------------------------------------------------------
  # VGA disabled (type = none) because GPU passthrough is used

  vga {
    type   = var.vm_vga_type
    memory = var.vm_vga_memory
  }

  # Enable tablet device for better mouse handling
  tablet_device = var.vm_tablet_device

  # -------------------------------------------------------------------------
  # SMBIOS Configuration
  # -------------------------------------------------------------------------
  # Custom SMBIOS values for hardware identification

  smbios {
    manufacturer = var.vm_smbios_manufacturer
    serial       = var.vm_smbios_serial
    uuid         = var.vm_smbios_uuid
    version      = var.vm_smbios_version
  }

  # -------------------------------------------------------------------------
  # PCI Passthrough Configuration (GPU and Audio Controllers)
  # -------------------------------------------------------------------------
  # Passes physical PCIe devices directly to the VM for native performance
  #
  # Prerequisites:
  # 1. IOMMU enabled in BIOS/UEFI (AMD: AMD-Vi, Intel: VT-d)
  # 2. IOMMU enabled in kernel boot parameters:
  #    AMD: amd_iommu=on iommu=pt
  #    Intel: intel_iommu=on iommu=pt
  # 3. vfio-pci kernel module loaded
  # 4. GPU isolated from host (bound to vfio-pci driver)
  #
  # Finding Your GPU Device ID:
  # On Proxmox host, run:
  #   lspci | grep -E "VGA|Audio"
  #
  # Example output:
  #   09:00.0 VGA compatible controller: AMD/ATI Radeon RX 580
  #   09:00.1 Audio device: AMD/ATI Radeon RX 580 HDMI Audio
  #
  # Convert to Proxmox format:
  #   09:00.0 → "0000:09:00"   (GPU)
  #   09:00.1 → "0000:09:00.1" (Audio)
  #
  # Configuration Parameters:
  # - device: Proxmox device identifier (hostpci0, hostpci1, etc.)
  # - id: PCI device ID in format "0000:BB:DD.F" (Bus:Device.Function)
  # - pcie: Enable PCIe passthrough (true for modern GPUs)
  # - rombar: Enable ROM BAR (GPU BIOS, usually true)
  # - xvga: Set as primary VGA output (true for main GPU, false for audio)
  #
  # Important Notes:
  # - VM VGA must be set to "none" when using GPU passthrough
  # - GPU and its audio device should be in same IOMMU group
  # - Only ONE GPU can be primary VGA (xvga=true)
  # - Some GPUs require specific ROM files for passthrough
  #
  # Troubleshooting GPU Passthrough:
  # - GPU not detected in VM: Check IOMMU groups, verify vfio-pci binding
  # - VM won't boot: Try different BIOS settings (Above 4G, resizable BAR)
  # - Black screen: Check GPU ROM BAR, try different romfile
  # - Code 43 error (NVIDIA): Add kvm=off to CPU flags
  #
  # Usage: Comment out these blocks if not using GPU passthrough

  # Primary GPU Passthrough (VGA Controller)
  hostpci {
    device = "hostpci0"
    id     = var.vm_hostpci0_id     # GPU PCI ID (e.g., "0000:09:00")
    pcie   = var.vm_hostpci0_pcie   # Enable PCIe (true for modern GPUs)
    rombar = var.vm_hostpci0_rombar # Enable ROM BAR (usually true)
    xvga   = var.vm_hostpci0_xvga   # Primary VGA (true for main display)
  }

  # GPU Audio Device Passthrough
  # Enables HDMI/DisplayPort audio output
  hostpci {
    device = "hostpci4"
    id     = var.vm_hostpci4_id     # Audio PCI ID (e.g., "0000:09:00.1")
    pcie   = var.vm_hostpci4_pcie   # PCIe (false for audio)
    rombar = var.vm_hostpci4_rombar # ROM BAR (usually true)
    xvga   = var.vm_hostpci4_xvga   # Not VGA (always false for audio)
  }

  # -------------------------------------------------------------------------
  # USB Device Passthrough Configuration
  # -------------------------------------------------------------------------
  # Passes USB devices directly to the VM for native device access
  #
  # Finding Your USB Devices:
  # On Proxmox host, run:
  #   lsusb
  #
  # Example output:
  #   Bus 001 Device 003: ID 046d:c328 Logitech, Inc. Corded Mouse M500
  #   Bus 004 Device 002: ID 413c:2113 Dell Computer Corp. KB216 Keyboard
  #
  # USB ID Formats (two options):
  #
  # Format 1: Vendor:Product ID (recommended for stable identification)
  #   Example: "046d:c328" (Logitech Mouse)
  #   Use when: Device may be plugged into different USB ports
  #   Note: All devices with same vendor:product will be passed through
  #
  # Format 2: Hub Port (specific port assignment)
  #   Example: "1-4" or "4-2.3" (Bus 4, Port 2, Subport 3)
  #   Use when: Need specific physical port passthrough
  #   Note: Device must remain in the same USB port
  #
  # USB 3.0 vs USB 2.0:
  # - usb3=true: Use for storage devices, high-speed peripherals
  # - usb3=false: Use for keyboards, mice (better compatibility)
  #
  # Important Notes:
  # - Passed-through USB devices are NOT accessible to Proxmox host
  # - Hot-plug support depends on guest OS and device drivers
  # - USB hubs can be passed through to passthrough all connected devices
  # - Some USB devices (webcams, audio) may need additional configuration
  #
  # Troubleshooting USB Passthrough:
  # - Device not found: Verify device ID with lsusb
  # - Device not working: Try different USB port or format
  # - Performance issues: Enable usb3 for high-bandwidth devices
  # - Device resets: Check power management settings in guest OS
  #
  # Usage: Comment out unused USB blocks or set host to empty string ""

  # USB Device 1: Keyboard or primary input
  usb {
    host = var.vm_usb_device_1_host # USB ID (e.g., "046d:c328" or "1-4")
    usb3 = var.vm_usb_device_1_usb3 # false for keyboards (better compatibility)
  }

  # USB Device 2: Mouse or secondary input
  usb {
    host = var.vm_usb_device_2_host # USB ID (e.g., "413c:2113" or "4-2")
    usb3 = var.vm_usb_device_2_usb3 # false for mice (better compatibility)
  }

  # USB Device 3: Additional peripheral or hub
  usb {
    host = var.vm_usb_device_3_host # USB ID (e.g., "0951:1666" or "4-2.3")
    usb3 = var.vm_usb_device_3_usb3 # true for storage devices
  }

  # USB Device 4: Storage or additional device
  usb {
    host = var.vm_usb_device_4_host # USB ID or empty "" if not used
    usb3 = var.vm_usb_device_4_usb3 # true for high-speed devices
  }

  # -------------------------------------------------------------------------
  # Timeout Configuration
  # -------------------------------------------------------------------------
  # Adjust timeouts for various VM operations

  timeout_create      = var.vm_timeout_create
  timeout_clone       = var.vm_timeout_clone
  timeout_start_vm    = var.vm_timeout_start_vm
  timeout_shutdown_vm = var.vm_timeout_shutdown_vm
  timeout_stop_vm     = var.vm_timeout_stop_vm
  timeout_reboot      = var.vm_timeout_reboot
  timeout_migrate     = var.vm_timeout_migrate
}