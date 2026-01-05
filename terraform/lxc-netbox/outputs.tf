# =============================================================================
# Outputs - LXC Netbox Container
# =============================================================================
#
# This file defines the output values exposed after Terraform applies the
# infrastructure configuration. Outputs provide important information about
# the created resources.
#
# Security Note: Passwords are marked as sensitive and will not be
# displayed in CLI output. Use `tofu output -raw <name>` to retrieve them.
#
# Usage:
#   tofu output                           # Show all non-sensitive outputs
#   tofu output -raw lxc_root_password    # Get container root password
#   tofu output -json                     # Get all outputs as JSON
#
# Author: HomeLab Infrastructure
# Last Updated: December 2025
# =============================================================================

# -----------------------------------------------------------------------------
# Container Information
# -----------------------------------------------------------------------------
output "s3_bucket_name_for_state" {
  description = "S3 bucket name used for Terraform state storage"
  value       = data.vault_generic_secret.s3_bucket_name.data["bucket_name"]
  sensitive   = true
}

output "lxc_id" {
  description = "Proxmox container ID (VMID)"
  value       = proxmox_virtual_environment_container.netbox.vm_id
}

output "lxc_hostname" {
  description = "Container hostname"
  value       = var.lxc_hostname
}

output "lxc_node" {
  description = "Proxmox node where container is running"
  value       = var.proxmox_node_name_vault_path
}

# -----------------------------------------------------------------------------
# Network Information
# -----------------------------------------------------------------------------

output "lxc_ip_address" {
  description = "Container IP address (may show 'dhcp' if using DHCP)"
  value       = var.lxc_ip_address
}

# -----------------------------------------------------------------------------
# Authentication Credentials
# -----------------------------------------------------------------------------

output "lxc_root_password" {
  description = "Container root password"
  value       = local.root_password
  sensitive   = true
}

# -----------------------------------------------------------------------------
# SSH Access Information
# -----------------------------------------------------------------------------

output "ssh_command" {
  description = "SSH command to access the container. Don't forget to use root user key for authentication."
  value       = var.lxc_ip_address == "dhcp" ? "ssh root@<container-ip>" : "ssh root@${split("/", var.lxc_ip_address)[0]}"
}

output "ssh_public_key_path" {
  description = "SSH public key used for authentication"
  value       = var.root_ssh_public_key_path
}

# -----------------------------------------------------------------------------
# Resource Summary
# -----------------------------------------------------------------------------

output "resource_summary" {
  description = "Summary of allocated resources"
  value = {
    cpu_cores = var.lxc_cpu_cores
    memory_mb = var.lxc_memory
    swap_mb   = var.lxc_swap
    disk_gb   = var.lxc_disk_size
    storage   = var.lxc_disk_storage
    template  = var.lxc_template_file
  }
}

# -----------------------------------------------------------------------------
# Ansible User Information
# -----------------------------------------------------------------------------

output "ansible_user_enabled" {
  description = "Whether Ansible user was created"
  value       = var.ansible_user_enabled
}

output "ansible_user_name" {
  description = "Ansible username (if enabled)"
  value       = var.ansible_user_enabled ? var.ansible_user_name : null
}

output "ansible_ssh_command" {
  description = "SSH command to connect as Ansible user. Don't forget to use the Ansible user key for authentication."
  value       = var.ansible_user_enabled ? "ssh ${var.ansible_user_name}@${var.lxc_ip_address == "dhcp" ? "<container-ip>" : split("/", var.lxc_ip_address)[0]}" : "Ansible user not enabled"
}

output "ansible_inventory_entry" {
  description = "Ansible inventory entry for this host in YAML format - Add this to your inventory.yml manually"
  value = var.ansible_user_enabled ? trimspace(<<-EOT
# Add this to scripts/ansible/inventory.yml under the 'netbox' group:
    netbox:
      hosts:
        ${var.lxc_hostname}:
          ansible_host: ${var.lxc_ip_address == "dhcp" ? "<container-ip>" : split("/", var.lxc_ip_address)[0]}
          ansible_port: 22
          ansible_user: ${var.ansible_user_name}
          ansible_python_interpreter: /usr/bin/python3
          ansible_ssh_private_key_file: ~/.ssh/ansible
      vars:
        ansible_become: true
        ansible_become_method: sudo
EOT
  ) : "Ansible user not enabled"
}

output "next_steps" {
  description = "Next steps to complete NetBox deployment"
  value = var.ansible_user_enabled ? trimspace(<<-EOT

================================================
✓ Infrastructure Deployed Successfully
================================================

Container Details:
  - Hostname: ${var.lxc_hostname}
  - IP Address: ${var.lxc_ip_address == "dhcp" ? "<check-container>" : split("/", var.lxc_ip_address)[0]}
  - VM ID: ${var.lxc_id}
  - Ansible User: ${var.ansible_user_name}

Next Steps:
  1. Verify SSH access to container:
     ssh ${var.ansible_user_name}@${var.lxc_ip_address == "dhcp" ? "<container-ip>" : split("/", var.lxc_ip_address)[0]}

  2. Manually add the host to your Ansible inventory:
     - See 'ansible_inventory_entry' output above for the exact configuration
     - Edit: ${path.root}/../../scripts/ansible/inventory.yml

  3. Deploy NetBox application using Ansible:
     cd ${path.root}/../../scripts/ansible
     ansible-playbook playbooks/netbox-deploy/site.yml

  4. After deployment, access NetBox web UI:
     http://${var.lxc_ip_address == "dhcp" ? "<container-ip>" : split("/", var.lxc_ip_address)[0]}

  5. Retrieve admin credentials from Vault:
     vault kv get secret/netbox/superuser

Documentation:
  - NetBox Docs: https://docs.netbox.dev/
  - Ansible Playbook: ${path.root}/../../scripts/ansible/playbooks/netbox-deploy/
EOT
  ) : "Ansible user not enabled - manual deployment required"
}
