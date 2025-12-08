# ╔════════════════════════════════════════════════════════════════════════════╗
# ║                     Fedora CoreOS VM - Main Configuration                  ║
# ║                                                                            ║
# ║  TWO-STAGE DEPLOYMENT APPROACH:                                            ║
# ║  1. OpenTofu: Creates VM (stopped) + generates Ignition config file        ║
# ║  2. Ansible:  Applies kvm_arguments with Ignition and starts VM            ║
# ║                                                                            ║
# ║  This approach avoids requiring root@pam password in OpenTofu.             ║
# ║  Ansible uses sudo on Proxmox host to run qm commands.                     ║
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

  # Image filename - use provided or construct from version
  fcos_image_filename = var.fcos_image_filename != "" ? var.fcos_image_filename : "fedora-coreos-${var.fcos_version}-proxmoxve.x86_64.qcow2"

  # Full path to local image on Proxmox host
  fcos_image_local_full_path = "${var.fcos_image_local_path}/${local.fcos_image_filename}"

  # Download URL (official images are .xz compressed)
  fcos_image_download_url = var.fcos_image_download_url != "" ? var.fcos_image_download_url : "https://builds.coreos.fedoraproject.org/prod/streams/${var.fcos_stream}/builds/${var.fcos_version}/x86_64/${local.fcos_image_filename}.xz"

  # Determine whether to use existing image or download new one
  use_existing_image = var.fcos_existing_file_id != ""

  # Final file_id for VM disk
  fcos_file_id = local.use_existing_image ? var.fcos_existing_file_id : proxmox_virtual_environment_download_file.fcos_image[0].id

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
  # Commas must be escaped as ,, for QEMU fw_cfg argument
  # --------------------------------------------------------------------------
  ignition_config_raw     = data.ct_config.vm_ignition.rendered
  ignition_config_escaped = replace(local.ignition_config_raw, ",", ",,")

  # --------------------------------------------------------------------------
  # Output paths for generated files
  # --------------------------------------------------------------------------
  ignition_output_dir  = "${path.module}/generated"
  ignition_output_file = "${local.ignition_output_dir}/${var.vm_name}-ignition.json"
  ansible_vars_file    = "${local.ignition_output_dir}/${var.vm_name}-ansible-vars.yml"
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
# Download FCOS Image to Proxmox Storage (Optional)
# Skipped if fcos_existing_file_id is provided.
# ------------------------------------------------------------------------------
resource "proxmox_virtual_environment_download_file" "fcos_image" {
  count = var.create_vm && !local.use_existing_image ? 1 : 0

  content_type = "iso"
  datastore_id = var.proxmox_iso_storage
  node_name    = var.proxmox_node

  url       = local.fcos_image_download_url
  file_name = local.fcos_image_filename
  overwrite = false
}

# ------------------------------------------------------------------------------
# Fedora CoreOS Virtual Machine
# 
# IMPORTANT: VM is created in STOPPED state without Ignition.
# Use the generated Ansible playbook to apply Ignition and start the VM.
# This avoids the need for root@pam password in OpenTofu.
# ------------------------------------------------------------------------------
resource "proxmox_virtual_environment_vm" "fcos" {
  count = var.create_vm ? 1 : 0

  # --------------------------------------------------------------------------
  # VM Identity
  # --------------------------------------------------------------------------
  vm_id       = var.vm_id
  name        = var.vm_name
  description = <<-EOT
    ${var.vm_description}
    
    ---
    IMPORTANT: This VM requires Ignition configuration.
    Run the Ansible playbook to apply Ignition and start the VM:
    
    ansible-playbook -i inventory.yml apply_fcos_ignition.yml -e @generated/${var.vm_name}-ansible-vars.yml
  EOT
  tags        = local.vm_tags
  node_name   = var.proxmox_node

  # --------------------------------------------------------------------------
  # VM Lifecycle - STOPPED by default (Ansible will start it)
  # --------------------------------------------------------------------------
  on_boot = var.vm_on_boot
  started = false # VM created stopped - Ansible will start after applying Ignition

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
    interface    = var.vm_disk_interface
    size         = parseint(replace(var.vm_disk_size, "/[GMT]/", ""), 10)
    datastore_id = var.vm_storage_pool
    file_format  = "raw"
    file_id      = local.fcos_file_id
    discard      = var.vm_disk_discard ? "on" : "ignore"
    ssd          = var.vm_disk_ssd_emulation
    iothread     = var.vm_disk_iothread
    cache        = "none"
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
  # Boot Configuration
  # --------------------------------------------------------------------------
  boot_order = [var.vm_boot_order]

  # --------------------------------------------------------------------------
  # NO kvm_arguments here - Ansible will apply them
  # --------------------------------------------------------------------------

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = [
      disk[0].file_id,
      description, # Description includes dynamic instructions
    ]
  }
}

# ==============================================================================
# GENERATED FILES FOR ANSIBLE
# ==============================================================================

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
# Save Ignition JSON to file
# This file will be used by Ansible to configure the VM
# ------------------------------------------------------------------------------
resource "local_file" "ignition_config" {
  count = var.create_vm ? 1 : 0

  content  = local.ignition_config_raw
  filename = local.ignition_output_file

  file_permission = "0600"

  depends_on = [null_resource.create_output_dir]
}

# ------------------------------------------------------------------------------
# Generate Ansible variables file
# Contains all necessary info for the Ansible playbook
# ------------------------------------------------------------------------------
resource "local_file" "ansible_vars" {
  count = var.create_vm ? 1 : 0

  content = yamlencode({
    # VM identification
    vm_id        = proxmox_virtual_environment_vm.fcos[0].vm_id
    vm_name      = var.vm_name
    proxmox_node = var.proxmox_node

    # Ignition configuration (escaped for qm args)
    ignition_config_escaped = local.ignition_config_escaped

    # Path to raw Ignition JSON (for reference/debugging)
    ignition_json_file = local.ignition_output_file

    # Network info for verification
    vm_ip_address = var.vm_ip_address != "" ? split("/", var.vm_ip_address)[0] : "dhcp"
    ssh_user      = var.ssh_user

    # Control flags
    start_vm_after_ignition = var.vm_started
    wait_for_ssh            = var.vm_started
    ssh_timeout             = "300"
  })

  filename        = local.ansible_vars_file
  file_permission = "0600"

  depends_on = [
    null_resource.create_output_dir,
    proxmox_virtual_environment_vm.fcos
  ]
}

# ==============================================================================
# OUTPUT INSTRUCTIONS
# ==============================================================================

resource "null_resource" "deployment_instructions" {
  count = var.create_vm ? 1 : 0

  triggers = {
    vm_id = proxmox_virtual_environment_vm.fcos[0].vm_id
  }

  provisioner "local-exec" {
    command = <<-EOF
      echo ""
      echo "╔══════════════════════════════════════════════════════════════════╗"
      echo "║           FEDORA COREOS VM CREATED SUCCESSFULLY                  ║"
      echo "╠══════════════════════════════════════════════════════════════════╣"
      echo "║  VM ID: ${proxmox_virtual_environment_vm.fcos[0].vm_id}"
      echo "║  Name:  ${var.vm_name}"
      echo "║  Node:  ${var.proxmox_node}"
      echo "║  State: STOPPED (awaiting Ignition configuration)"
      echo "╠══════════════════════════════════════════════════════════════════╣"
      echo "║  NEXT STEP: Run Ansible playbook to apply Ignition and start VM  ║"
      echo "╠══════════════════════════════════════════════════════════════════╣"
      echo "║  cd ../.. && ansible-playbook -i scripts/ansible_playbooks/inventory.yml \\"
      echo "║     scripts/ansible_playbooks/apply_fcos_ignition.yml \\"
      echo "║     -e @terraform/fedora_core/generated/${var.vm_name}-ansible-vars.yml"
      echo "╚══════════════════════════════════════════════════════════════════╝"
      echo ""
    EOF
  }

  depends_on = [
    local_file.ignition_config,
    local_file.ansible_vars
  ]
}

# ==============================================================================
# END OF MAIN CONFIGURATION
# ==============================================================================
