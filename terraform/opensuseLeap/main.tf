# =============================================================================
# OpenSUSE Leap 16 Virtual Machine Configuration
# =============================================================================
# This configuration manages an OpenSUSE Leap 16 workstation with GPU
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
#
# IMPORTANT: To import an existing VM under OpenTofu management:
# 1. Configure variables for the correct node_name and vm_id
# 2. Run: tofu import proxmox_virtual_environment_vm.opensuseLeap16 <vm_id>
# 3. Run: tofu plan to see the configuration drift
# 4. Update this file to match the actual configuration
# ============================================================================

# -----------------------------------------------------------------------------
# Main VM Resource: openSUSE Leap 16 Workstation
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_vm" "opensuseLeap16" {
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
  started                              = var.vm_started
  stop_on_destroy                      = var.vm_stop_on_destroy
  template                             = false
  migrate                              = false
  reboot                               = false
  protection                           = var.vm_protection
  delete_unreferenced_disks_on_destroy = true
  purge_on_destroy                     = true
  reboot_after_update                  = true

  # Lifecycle protection to prevent accidental deletion
  # Uncomment to prevent VM destruction via tofu destroy
  lifecycle {
    # prevent_destroy = true
    ignore_changes = [
      # Ignore MAC address changes (can vary after reboot)
      # network_device[0].mac_address,
    ]
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
  # High-performance CPU configuration with host passthrough

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

  # KVM Arguments for Hyper-V enlightenments (improves Windows/Linux performance)
  kvm_arguments = var.vm_kvm_arguments

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
  # Main Boot Disk
  # -------------------------------------------------------------------------
  # High-performance disk configuration with io_uring and writeback cache

  disk {
    datastore_id = var.vm_disk_datastore_id
    interface    = var.vm_disk_interface
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
  # PCI Passthrough Configuration
  # -------------------------------------------------------------------------
  # GPU and Audio Controller Passthrough

  # Primary GPU (AMD Radeon)
  hostpci {
    device = "hostpci0"
    id     = var.vm_hostpci0_id
    pcie   = var.vm_hostpci0_pcie
    rombar = var.vm_hostpci0_rombar
    xvga   = var.vm_hostpci0_xvga
  }

  # Audio Device (AMD GPU Audio)
  hostpci {
    device = "hostpci4"
    id     = var.vm_hostpci4_id
    pcie   = var.vm_hostpci4_pcie
    rombar = var.vm_hostpci4_rombar
    xvga   = var.vm_hostpci4_xvga
  }

  # -------------------------------------------------------------------------
  # USB Device Passthrough
  # -------------------------------------------------------------------------
  # Passing through keyboard, mouse, and other USB devices

  # USB Device 1: Keyboard or primary input
  usb {
    host = var.vm_usb_device_1_host
    usb3 = var.vm_usb_device_1_usb3
  }

  # USB Device 2: Mouse or secondary input
  usb {
    host = var.vm_usb_device_2_host
    usb3 = var.vm_usb_device_2_usb3
  }

  # USB Device 3: Additional peripheral or hub
  usb {
    host = var.vm_usb_device_3_host
    usb3 = var.vm_usb_device_3_usb3
  }

  # USB Device 4: Storage or additional device
  usb {
    host = var.vm_usb_device_4_host
    usb3 = var.vm_usb_device_4_usb3
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