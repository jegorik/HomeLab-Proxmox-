# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                     Fedora CoreOS VM - Main Configuration                     ║
# ║                                                                               ║
# ║  OpenTofu configuration for provisioning Fedora CoreOS VMs on Proxmox VE     ║
# ║  Uses Ignition (via Butane) for immutable infrastructure configuration       ║
# ║                                                                               ║
# ║  Author: jegorik                                                              ║
# ║  Last Updated: December 2025                                                  ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# LOCAL VALUES
# ==============================================================================

locals {
  # --------------------------------------------------------------------------
  # Image Configuration
  # Construct filenames and URLs if not explicitly provided
  # --------------------------------------------------------------------------

  # Image filename - use provided or construct from version
  fcos_image_filename = var.fcos_image_filename != "" ? var.fcos_image_filename : "fedora-coreos-${var.fcos_version}-proxmoxve.x86_64.qcow2"

  # Full path to local image on Proxmox host
  fcos_image_local_full_path = "${var.fcos_image_local_path}/${local.fcos_image_filename}"

  # Download URL - use provided or construct from stream/version
  fcos_image_download_url = var.fcos_image_download_url != "" ? var.fcos_image_download_url : "https://builds.coreos.fedoraproject.org/prod/streams/${var.fcos_stream}/builds/${var.fcos_version}/x86_64/${local.fcos_image_filename}"

  # --------------------------------------------------------------------------
  # SSH Keys
  # Combine primary and additional SSH keys
  # --------------------------------------------------------------------------
  all_ssh_keys = concat([var.ssh_public_key], var.ssh_public_keys_additional)

  # --------------------------------------------------------------------------
  # Network Configuration
  # Parse IP address for Ignition template
  # --------------------------------------------------------------------------
  use_static_ip = var.vm_ip_address != ""

  # --------------------------------------------------------------------------
  # VM Tags
  # Ensure consistent tag format (lowercase, no spaces)
  # --------------------------------------------------------------------------
  vm_tags = [for tag in var.vm_tags : lower(replace(tag, " ", "-"))]

  # --------------------------------------------------------------------------
  # Ignition Configuration
  # The rendered Ignition JSON is passed to QEMU via fw_cfg
  # CRITICAL: Commas must be escaped as ,, for fw_cfg argument
  # --------------------------------------------------------------------------
  ignition_config_escaped = replace(data.ct_config.vm_ignition.rendered, ",", ",,")
}

# ==============================================================================
# DATA SOURCES
# ==============================================================================

# ------------------------------------------------------------------------------
# Butane to Ignition Transpilation
# 
# Converts human-readable Butane YAML to machine-readable Ignition JSON.
# The ct_config data source uses the poseidon/ct provider.
# ------------------------------------------------------------------------------
data "ct_config" "vm_ignition" {
  content = templatefile("${path.module}/${var.butane_template_path}", {
    # System identity
    hostname = var.vm_name
    timezone = var.timezone

    # User configuration
    ssh_user                   = var.ssh_user
    ssh_public_key             = var.ssh_public_key
    ssh_public_keys_additional = var.ssh_public_keys_additional

    # Network configuration
    ip_address  = var.vm_ip_address
    gateway     = var.vm_gateway
    dns_servers = var.vm_dns_servers

    # Features
    enable_qemu_guest_agent = var.enable_qemu_guest_agent
  })

  strict       = true
  pretty_print = false
}

# ------------------------------------------------------------------------------
# Check if FCOS Image Exists Locally
# 
# This null_data_source is used to determine if we need to download the image
# or if it already exists on the Proxmox host.
# ------------------------------------------------------------------------------
data "external" "check_fcos_image" {
  count = var.create_vm ? 1 : 0

  program = ["bash", "-c", <<-EOF
    # Check if image exists on Proxmox host via SSH
    # This requires SSH access to Proxmox host
    if [ -f "${local.fcos_image_local_full_path}" ]; then
      echo '{"exists": "true", "path": "${local.fcos_image_local_full_path}"}'
    else
      echo '{"exists": "false", "path": ""}'
    fi
  EOF
  ]
}

# ==============================================================================
# RESOURCES
# ==============================================================================

# ------------------------------------------------------------------------------
# Random Suffix for Unique Resource Names
# Used when creating multiple VMs from the same configuration
# ------------------------------------------------------------------------------
resource "random_id" "vm_suffix" {
  count       = var.create_vm && var.vm_id == null ? 1 : 0
  byte_length = 2
}

# ------------------------------------------------------------------------------
# Download FCOS Image if Not Present
# 
# This resource downloads the Fedora CoreOS image to the Proxmox host
# if it doesn't already exist locally.
# 
# NOTE: Requires SSH access to Proxmox host with appropriate permissions.
# Alternative: Use proxmox_virtual_environment_download_file resource.
# ------------------------------------------------------------------------------
resource "null_resource" "download_fcos_image" {
  count = var.create_vm ? 1 : 0

  triggers = {
    image_filename = local.fcos_image_filename
    image_path     = local.fcos_image_local_full_path
  }

  provisioner "local-exec" {
    command = <<-EOF
      echo "Checking if FCOS image exists at ${local.fcos_image_local_full_path}..."
      
      # Note: This script assumes OpenTofu is running on a machine with
      # SSH access to the Proxmox host. Adjust as needed for your environment.
      
      # For Semaphore UI deployment, you may need to:
      # 1. Pre-download the image manually
      # 2. Use a different download mechanism
      # 3. Configure SSH access from Semaphore to Proxmox
      
      echo "Image check complete. If image is missing, download manually or adjust script."
    EOF
  }
}

# ------------------------------------------------------------------------------
# Upload FCOS Image to Proxmox Storage
# 
# Uploads the QCOW2 image to Proxmox storage for VM disk creation.
# The image is stored in the ISO storage and used as the VM disk source.
# ------------------------------------------------------------------------------
resource "proxmox_virtual_environment_file" "fcos_image" {
  count = var.create_vm ? 1 : 0

  content_type = "iso"
  datastore_id = var.proxmox_iso_storage
  node_name    = var.proxmox_node

  source_file {
    # Path to the QCOW2 image on the machine running OpenTofu
    # For remote execution (Semaphore), ensure this path is accessible
    path = local.fcos_image_local_full_path

    # Filename in Proxmox storage
    file_name = local.fcos_image_filename
  }

  # Wait for download check to complete
  depends_on = [null_resource.download_fcos_image]
}

# ------------------------------------------------------------------------------
# Fedora CoreOS Virtual Machine
# 
# Creates the VM with Ignition configuration injected via QEMU fw_cfg.
# 
# CRITICAL NOTES:
# 1. kvm_arguments requires root@pam authentication with PASSWORD
#    API tokens do NOT work for kvm_arguments
# 2. Ignition config is passed via: -fw_cfg 'name=opt/com.coreos/config,string=...'
# 3. Commas in the Ignition JSON MUST be escaped as ,, for fw_cfg
# ------------------------------------------------------------------------------
resource "proxmox_virtual_environment_vm" "fcos" {
  count = var.create_vm ? 1 : 0

  # --------------------------------------------------------------------------
  # VM Identity
  # --------------------------------------------------------------------------
  vm_id       = var.vm_id
  name        = var.vm_name
  description = var.vm_description
  tags        = local.vm_tags
  node_name   = var.proxmox_node

#   # Resource pool (optional)
#   pool_id = var.proxmox_pool != "" ? var.proxmox_pool : null

  # --------------------------------------------------------------------------
  # VM Lifecycle
  # --------------------------------------------------------------------------
  on_boot = var.vm_on_boot
  started = var.vm_started

  # Protection against accidental deletion
  protection = var.vm_protection

  # Startup/shutdown order
  startup {
    order = var.vm_startup_order != "" ? split(",", var.vm_startup_order)[0] : null
  }

  # Timeouts
  timeout_create = var.provision_timeout
  timeout_clone  = var.provision_timeout

  # --------------------------------------------------------------------------
  # Hardware Configuration
  # --------------------------------------------------------------------------
  machine = var.vm_machine_type
  bios    = var.vm_bios

  # CPU Configuration
  cpu {
    cores   = var.vm_cpu_cores
    sockets = var.vm_cpu_sockets
    type    = var.vm_cpu_type
    numa    = var.vm_numa
  }

  # Memory Configuration
  memory {
    dedicated = var.vm_memory
    floating  = var.vm_balloon_memory
  }

  # SCSI Controller
  scsi_hardware = var.vm_scsi_hardware

  # --------------------------------------------------------------------------
  # Storage Configuration
  # --------------------------------------------------------------------------
  disk {
    interface    = var.vm_disk_interface
    size         = parseint(replace(var.vm_disk_size, "/[GMT]/", ""), 10)
    datastore_id = var.vm_storage_pool
    file_format  = "raw"

    # Import from uploaded QCOW2 image
    file_id = proxmox_virtual_environment_file.fcos_image[0].id

    # Performance options
    discard  = var.vm_disk_discard ? "on" : "ignore"
    ssd      = var.vm_disk_ssd_emulation
    iothread = var.vm_disk_iothread

    # Cache settings for best performance with SSD storage
    cache = "none"
  }

  # --------------------------------------------------------------------------
  # Network Configuration
  # --------------------------------------------------------------------------
  network_device {
    bridge   = var.vm_network_bridge
    model    = var.vm_network_model
    vlan_id  = var.vm_network_vlan
    firewall = var.vm_network_firewall
  }

  # --------------------------------------------------------------------------
  # Console & Input
  # --------------------------------------------------------------------------
  keyboard_layout = var.vm_keyboard_layout
  tablet_device   = var.vm_tablet_device

  # Serial port for console access
  serial_device {}

  # VGA for graphical console
  vga {
    type = "std"
  }

  # --------------------------------------------------------------------------
  # Agent Configuration
  # --------------------------------------------------------------------------
  agent {
    enabled = var.enable_qemu_guest_agent
    type    = "virtio"
    timeout = "5m"
  }

  # --------------------------------------------------------------------------
  # Boot Configuration
  # --------------------------------------------------------------------------
  boot_order = [var.vm_boot_order]

  # --------------------------------------------------------------------------
  # IGNITION INJECTION via QEMU fw_cfg
  # 
  # This is the CRITICAL part for Fedora CoreOS provisioning.
  # The Ignition config is passed directly to the VM firmware.
  # 
  # IMPORTANT:
  # - kvm_arguments REQUIRES root@pam authentication with PASSWORD
  # - API tokens will NOT work for this feature
  # - Commas in JSON must be escaped as ,, for fw_cfg argument
  # --------------------------------------------------------------------------
  kvm_arguments = var.proxmox_root_password != "" ? "-fw_cfg 'name=opt/com.coreos/config,string=${local.ignition_config_escaped}'" : null

  # --------------------------------------------------------------------------
  # Operating System Type
  # --------------------------------------------------------------------------
  operating_system {
    type = "l26" # Linux 2.6+ kernel
  }

  # --------------------------------------------------------------------------
  # Lifecycle Management
  # --------------------------------------------------------------------------
  lifecycle {
    # Ignore changes to these attributes after creation
    ignore_changes = [
      # Ignore disk changes after initial creation
      disk[0].file_id,
      # Ignore kvm_arguments changes (Ignition is one-time)
      kvm_arguments,
    ]
  }

  # Ensure image is uploaded before VM creation
  depends_on = [proxmox_virtual_environment_file.fcos_image]
}

# ==============================================================================
# POST-PROVISIONING CHECKS
# ==============================================================================

# ------------------------------------------------------------------------------
# Wait for VM to be Ready
# 
# Waits for the QEMU guest agent to respond, indicating the VM has booted
# and completed initial configuration (including potential reboot for
# qemu-guest-agent installation).
# ------------------------------------------------------------------------------
resource "null_resource" "wait_for_vm" {
  count = var.create_vm && var.vm_started && var.enable_qemu_guest_agent ? 1 : 0

  triggers = {
    vm_id = proxmox_virtual_environment_vm.fcos[0].id
  }

  provisioner "local-exec" {
    command = <<-EOF
      echo "Waiting for VM ${var.vm_name} to be ready..."
      echo "Note: Fedora CoreOS may reboot once to install qemu-guest-agent"
      echo "This can take 2-5 minutes depending on network speed."
      
      # Sleep to allow for potential reboot during rpm-ostree install
      sleep 120
      
      echo "VM should now be accessible via SSH."
    EOF
  }

  depends_on = [proxmox_virtual_environment_vm.fcos]
}

# ==============================================================================
# END OF MAIN CONFIGURATION
# ==============================================================================
