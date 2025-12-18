# =============================================================================
# Cloud-Init Configuration for Automated User Provisioning
# =============================================================================
# This file manages cloud-init user data snippets stored in Proxmox storage.
# It creates and uploads a cloud-init configuration template that provisions:
# - Ansible automation service account (passwordless sudo)
# - Administrative user with sudo access (password-protected sudo)
# - SSH key authentication for both users (no password login)
# - System hardening (SSH configuration, firewall setup)
# - Essential package installation (qemu-agent, development tools, Python)
#
# Cloud-Init Workflow:
# 1. SSH keys are read from local files (specified in variables)
# 2. user-config.yaml template is populated with variables
# 3. Snippet is uploaded to Proxmox storage (requires "snippets" content type)
# 4. VM boots and cloud-init executes the configuration
# 5. Users are created with SSH keys configured
# 6. Packages are installed and system is hardened
#
# Prerequisites:
# - Proxmox storage must have "snippets" content type enabled
#   Command: pvesm set local --content iso,vztmpl,snippets
# - SSH public keys must exist at specified paths
#   Generate: ssh-keygen -t ed25519 -f ~/.ssh/ansible_key -N ""
#            ssh-keygen -t ed25519 -f ~/.ssh/admin_key -N ""
# - cloud-init/user-config.yaml template must exist
#
# Troubleshooting:
# - "snippets not enabled": Run pvesm set <storage> --content snippets
# - "file not found": Verify SSH key paths in terraform.tfvars
# - "permission denied": Check SSH key file permissions (should be 644 for .pub)
# - Cloud-init not running: Check /var/log/cloud-init.log in VM
# =============================================================================

# -----------------------------------------------------------------------------
# Local Variables: SSH Key Reading and Validation
# -----------------------------------------------------------------------------
# Reads SSH public keys from local filesystem with error handling
# The trimspace() function removes any trailing newlines or whitespace
# Empty string is used as fallback if path is not provided

locals {
  # Ansible service account SSH public key
  # Used for automation and configuration management
  # Should be passwordless sudo for automated operations
  ansible_ssh_key = var.ansible_ssh_key_path != "" ? trimspace(file(var.ansible_ssh_key_path)) : ""

  # Administrative user SSH public key
  # Used for manual system administration and maintenance
  # Should require password for sudo operations (security)
  admin_ssh_key = var.admin_ssh_key_path != "" ? trimspace(file(var.admin_ssh_key_path)) : ""
}

# =============================================================================
# Trigger Resource for Cloud-Init Configuration Changes
# =============================================================================
# This resource uses the terraform_data resource to track changes in cloud-init
# configuration variables. When any tracked variable changes, it triggers
# replacement of the cloud-init snippet file in Proxmox storage.
#
# Tracked Variables:
# - admin_username: Name of the administrative user to create
# - ansible_key: SSH public key for Ansible service account
# - admin_key: SSH public key for administrative user
# - hostname: VM hostname (affects cloud-init identity)
#
# Why This Matters:
# Without this trigger, changing SSH keys or usernames would not update the
# cloud-init snippet, causing new VMs to use old configuration. The trigger
# ensures the snippet is always synchronized with current variables.
#
# Usage Pattern (Advanced):
# This pattern is useful for any configuration file that needs to be
# regenerated when input variables change, especially for immutable
# infrastructure where file content must match declared state.

resource "terraform_data" "cloud_init_trigger" {
  count = var.cloudinit_enabled ? 1 : 0

  input = {
    admin_username = var.cloudinit_admin_username
    ansible_key    = local.ansible_ssh_key
    admin_key      = local.admin_ssh_key
    hostname       = var.vm_name
  }
}

# =============================================================================
# Cloud-Init User Data Snippet Resource
# =============================================================================
# Uploads cloud-init user data configuration to Proxmox storage as a snippet.
# This snippet is then referenced by the VM configuration during initialization.
#
# How It Works:
# 1. templatefile() function reads cloud-init/user-config.yaml
# 2. Variables (hostname, usernames, SSH keys) are injected into template
# 3. Resulting YAML is uploaded to Proxmox storage as a snippet
# 4. VM references this snippet via initialization.user_data_file_id
# 5. On first boot, cloud-init reads snippet and applies configuration
#
# Storage Requirements:
# - Datastore must have "snippets" content type enabled
# - Verify with: pvesm status | grep snippets
# - Enable with: pvesm set <datastore> --content iso,vztmpl,snippets
#
# Template Variables Injected:
# - ${hostname}: VM hostname (from var.vm_name)
# - ${admin_username}: Admin user account name
# - ${ansible_ssh_key}: Public SSH key for Ansible user
# - ${admin_ssh_key}: Public SSH key for admin user
#
# File Location in Proxmox:
# - Path: /var/lib/vz/snippets/cloud-init-<vm_name>-user-config.yaml
# - Accessible via: Datacenter > Storage > Snippets
#
# Troubleshooting:
# - "content type not enabled": Enable snippets on storage
# - "file upload failed": Check SSH connectivity to Proxmox host
# - "template not found": Verify cloud-init/user-config.yaml exists
# - "invalid YAML": Check syntax in user-config.yaml template

resource "proxmox_virtual_environment_file" "cloud_init_user_config" {
  count = var.cloudinit_enabled ? 1 : 0

  content_type = "snippets"
  datastore_id = var.vm_snippets_datastore_id
  node_name    = var.proxmox_node_name

  source_raw {
    # Use templatefile() to inject variables into cloud-init template
    # The template uses ${variable_name} syntax for substitution
    data = templatefile("${path.module}/cloud-init/user-config.yaml", {
      hostname        = var.vm_name
      admin_username  = var.cloudinit_admin_username
      ansible_ssh_key = local.ansible_ssh_key
      admin_ssh_key   = local.admin_ssh_key
    })

    # File name in Proxmox storage (visible in GUI)
    # Format: cloud-init-<vm_name>-user-config.yaml
    file_name = "cloud-init-${var.vm_name}-user-config.yaml"
  }

  # Recreate snippet file when trigger resource detects changes
  # This ensures cloud-init configuration stays synchronized with variables
  lifecycle {
    replace_triggered_by = [terraform_data.cloud_init_trigger[0]]
  }
}
