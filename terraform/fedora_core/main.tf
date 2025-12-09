# ╔════════════════════════════════════════════════════════════════════════════╗
# ║                     Fedora CoreOS VM - Main Configuration                  ║
# ║                                                                            ║
# ║  SINGLE-STAGE CLOUD-INIT DEPLOYMENT:                                       ║
# ║  OpenTofu creates VM with Ignition config delivered via Proxmox Cloud-Init ║
# ║                                                                            ║
# ║  Based on official Fedora CoreOS documentation (December 2025):            ║
# ║  https://docs.fedoraproject.org/en-US/fedora-coreos/provisioning-proxmoxve ║
# ║                                                                            ║
# ║  Prerequisites:                                                            ║
# ║  - Run scripts/bash/setup/proxmox_fcos_storage_setup.sh on Proxmox host    ║
# ║  - Creates /var/coreos storage with images and snippets directories        ║
# ║                                                                            ║
# ║  Author: jegorik                                                           ║
# ║  Last Updated: December 2025                                               ║
# ╚════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# LOCAL VALUES
# ==============================================================================

locals {
  # --------------------------------------------------------------------------
  # Image Configuration
  # --------------------------------------------------------------------------

  # Image path on Proxmox host (in /var/coreos/images/)
  fcos_image_filename = var.fcos_image_filename != "" ? var.fcos_image_filename : "fedora-coreos-${var.fcos_version}-proxmoxve.x86_64.qcow2"
  
  # Full path for import-from parameter
  fcos_image_path = "${var.coreos_storage_path}/images/${local.fcos_image_filename}"

  # --------------------------------------------------------------------------
  # SSH Keys
  # --------------------------------------------------------------------------
  all_ssh_keys = concat([var.ssh_public_key], var.ssh_public_keys_additional)

  # --------------------------------------------------------------------------
  # VM Tags
  # --------------------------------------------------------------------------
  vm_tags = [for tag in var.vm_tags : lower(replace(tag, " ", "-"))]

  # --------------------------------------------------------------------------
  # Ignition Configuration
  # --------------------------------------------------------------------------
  ignition_config_raw = data.ct_config.vm_ignition.rendered
  
  # Ignition filename for snippets storage
  ignition_snippet_name = "${var.vm_name}.ign"

  # --------------------------------------------------------------------------
  # Output paths for generated files
  # --------------------------------------------------------------------------
  ignition_output_dir  = "${path.module}/generated"
  ignition_output_file = "${local.ignition_output_dir}/${local.ignition_snippet_name}"
}

# ==============================================================================
# DATA SOURCES
# ==============================================================================

# ------------------------------------------------------------------------------
# Butane to Ignition Transpilation
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

# ==============================================================================
# RESOURCES
# ==============================================================================

# ------------------------------------------------------------------------------
# Random Suffix for Unique Resource Names
# ------------------------------------------------------------------------------
resource "random_id" "vm_suffix" {
  count       = var.create_vm && var.vm_id == null ? 1 : 0
  byte_length = 2
}

# ------------------------------------------------------------------------------
# Create output directory for generated files
# ------------------------------------------------------------------------------
resource "null_resource" "create_output_dir" {
  count = var.create_vm ? 1 : 0

  provisioner "local-exec" {
    command = "mkdir -p ${local.ignition_output_dir}"
  }
}

# ------------------------------------------------------------------------------
# Save Ignition JSON to local file
# ------------------------------------------------------------------------------
resource "local_file" "ignition_config" {
  count = var.create_vm ? 1 : 0

  content  = local.ignition_config_raw
  filename = local.ignition_output_file

  file_permission = "0600"

  depends_on = [null_resource.create_output_dir]
}

# ------------------------------------------------------------------------------
# Upload Ignition to Proxmox snippets storage
# Uses SCP to transfer the file to /var/coreos/snippets/
# ------------------------------------------------------------------------------
resource "null_resource" "upload_ignition" {
  count = var.create_vm ? 1 : 0

  triggers = {
    ignition_content = local.ignition_config_raw
    vm_name          = var.vm_name
  }

  provisioner "local-exec" {
    command = <<-EOF
      scp -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -i <(echo "${var.proxmox_ssh_private_key}") \
          ${local.ignition_output_file} \
          ${var.proxmox_ssh_user}@${var.proxmox_host}:${var.coreos_storage_path}/snippets/${local.ignition_snippet_name}
    EOF
  }

  depends_on = [local_file.ignition_config]
}

# ------------------------------------------------------------------------------
# Fedora CoreOS Virtual Machine
# 
# Uses Cloud-Init to deliver Ignition configuration via vendor data.
# VM starts automatically with Ignition applied on first boot.
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

  # --------------------------------------------------------------------------
  # VM Lifecycle
  # --------------------------------------------------------------------------
  on_boot = var.vm_on_boot
  started = var.vm_started # VM starts automatically with Ignition

  protection = var.vm_protection

  startup {
    order = var.vm_startup_order != "" ? split(",", var.vm_startup_order)[0] : null
  }

  timeout_create = var.provision_timeout
  timeout_clone  = var.provision_timeout

  # --------------------------------------------------------------------------
  # Hardware Configuration
  # --------------------------------------------------------------------------
  machine = var.vm_machine_type
  bios    = var.vm_bios

  cpu {
    cores   = var.vm_cpu_cores
    sockets = var.vm_cpu_sockets
    type    = var.vm_cpu_type
    numa    = var.vm_numa
  }

  memory {
    dedicated = var.vm_memory
    floating  = var.vm_balloon_memory
  }

  scsi_hardware = var.vm_scsi_hardware

  # --------------------------------------------------------------------------
  # Storage Configuration
  # --------------------------------------------------------------------------
  disk {
    datastore_id = var.vm_storage_pool
    interface    = var.vm_disk_interface
    size         = parseint(replace(var.vm_disk_size, "/[GMT]/", ""), 10)
    ssd          = var.vm_disk_ssd_emulation
    discard      = var.vm_disk_discard ? "on" : "ignore"
    iothread     = var.vm_disk_iothread
    cache        = "none"
    
    # Import FCOS image from coreos storage
    file_format = "qcow2"
    import_from = local.fcos_image_path
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
  # Console & Display
  # --------------------------------------------------------------------------
  keyboard_layout = var.vm_keyboard_layout
  tablet_device   = var.vm_tablet_device

  serial_device {}

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
  # Cloud-Init Configuration
  # Delivers Ignition config via vendor data (official Proxmox method)
  # --------------------------------------------------------------------------
  initialization {
    vendor_data_file_id = "${var.coreos_storage}:snippets/${local.ignition_snippet_name}"
  }

  # VM depends on Ignition file being uploaded to Proxmox
  depends_on = [null_resource.upload_ignition]
}

# ==============================================================================
# DEPLOYMENT INSTRUCTIONS
# ==============================================================================

resource "null_resource" "deployment_instructions" {
  count = var.create_vm ? 1 : 0

  triggers = {
    vm_id = proxmox_virtual_environment_vm.fcos[0].vm_id
  }

  provisioner "local-exec" {
    command = <<-EOF
      echo ""
      echo "========================================================================"
      echo "       FEDORA COREOS VM DEPLOYED SUCCESSFULLY"
      echo "========================================================================"
      echo "  VM ID:   ${proxmox_virtual_environment_vm.fcos[0].vm_id}"
      echo "  Name:    ${var.vm_name}"
      echo "  Node:    ${var.proxmox_node}"
      echo "  Status:  ${var.vm_started ? "STARTING" : "STOPPED"}"
      echo "========================================================================"
      echo "  Ignition config applied via Cloud-Init vendor data"
      echo "  Location: ${var.coreos_storage}:snippets/${local.ignition_snippet_name}"
      echo "========================================================================"
      echo ""
    EOF
  }

  depends_on = [
    proxmox_virtual_environment_vm.fcos,
    local_file.ignition_config
  ]
}

# ==============================================================================
# END OF MAIN CONFIGURATION
# ==============================================================================
