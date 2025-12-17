# =============================================================================
# Cloud-Init Configuration for User Provisioning
# =============================================================================
# This file manages cloud-init user data snippets stored in Proxmox.
# It creates and uploads a cloud-init configuration template that provisions:
# - Ansible automation service account
# - Administrative user with sudo access
# - SSH key authentication for both users
# - System hardening and package installation
# =============================================================================

# Read SSH public keys from files with validation
locals {
  # Ansible service account SSH key
  ansible_ssh_key = var.ansible_ssh_key_path != "" ? trimspace(file(var.ansible_ssh_key_path)) : ""
  
  # Admin user SSH key
  admin_ssh_key = var.admin_ssh_key_path != "" ? trimspace(file(var.admin_ssh_key_path)) : ""
}

# =============================================================================
# Cloud-Init User Data Snippet
# =============================================================================
# Upload cloud-init configuration as a Proxmox snippet for VM provisioning
# Requires: Proxmox storage configured with "snippets" content type
# Manual prerequisite: pvesm set local --content iso,vztmpl,snippets

resource "proxmox_virtual_environment_file" "cloud_init_user_config" {
  count = var.cloudinit_enabled ? 1 : 0

  content_type = "snippets"
  datastore_id = var.vm_disk_datastore_id
  node_name    = var.proxmox_node_name

  source_raw {
    # Use templatefile to inject variables into cloud-init template
    data = templatefile("${path.module}/cloud-init/user-config.yaml.tpl", {
      hostname         = var.vm_name
      admin_username   = var.cloudinit_admin_username
      ansible_ssh_key  = local.ansible_ssh_key
      admin_ssh_key    = local.admin_ssh_key
    })

    # File name for identification in Proxmox
    file_name = "cloud-init-${var.vm_name}-user-config.yaml"
  }

  # Recreate snippet if variables change
  lifecycle {
    replace_triggered_by = [var.cloudinit_admin_username]
  }
}
