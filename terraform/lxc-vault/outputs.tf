# =============================================================================
# Outputs - LXC Vault Container
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

output "lxc_id" {
  description = "Proxmox container ID (VMID)"
  value       = proxmox_virtual_environment_container.vault.vm_id
}

output "lxc_hostname" {
  description = "Container hostname"
  value       = var.lxc_hostname
}

output "lxc_node" {
  description = "Proxmox node where container is running"
  value       = var.proxmox_node
}

# -----------------------------------------------------------------------------
# Network Information
# -----------------------------------------------------------------------------

output "lxc_ip_address" {
  description = "Container IP address (may show 'dhcp' if using DHCP)"
  value       = var.lxc_ip_address
}

output "vault_url" {
  description = "Vault web interface URL"
  value       = var.lxc_ip_address == "dhcp" ? "http://<container-ip>:${var.vault_port}" : "http://${split("/", var.lxc_ip_address)[0]}:${var.vault_port}"
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
  description = "SSH command to access the container"
  value       = var.lxc_ip_address == "dhcp" ? "ssh root@<container-ip>" : "ssh root@${split("/", var.lxc_ip_address)[0]}"
}

output "ssh_public_key_path" {
  description = "Path to SSH public key used for authentication"
  value       = var.ssh_public_key_path
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
  description = "SSH command to connect as Ansible user"
  value       = var.ansible_user_enabled ? "ssh ${var.ansible_user_name}@${var.lxc_ip_address == "dhcp" ? "<container-ip>" : split("/", var.lxc_ip_address)[0]}" : "Ansible user not enabled"
}

output "ansible_inventory_entry" {
  description = "Ansible inventory entry for this host"
  value = var.ansible_user_enabled ? trimspace(<<-EOT
${var.lxc_hostname}:
  ansible_host: ${var.lxc_ip_address == "dhcp" ? "<container-ip>" : split("/", var.lxc_ip_address)[0]}
  ansible_user: ${var.ansible_user_name}
  ansible_ssh_private_key_file: ${replace(var.ansible_ssh_public_key_path, ".pub", "")}
  ansible_python_interpreter: /usr/bin/python3
EOT
  ) : "Ansible user not enabled"
}

# -----------------------------------------------------------------------------
# Post-Deployment Instructions
# -----------------------------------------------------------------------------

output "next_steps" {
  description = "Critical post-deployment steps"
  value = <<-EOT
    ╔════════════════════════════════════════════════════════════════╗
    ║          VAULT DEPLOYMENT SUCCESSFUL - NEXT STEPS             ║
    ╚════════════════════════════════════════════════════════════════╝

    ⚠️  CRITICAL: Secure Your Vault Initialization Keys!

    1. Retrieve initialization keys (contains unseal keys and root token):
       scp root@${var.lxc_ip_address == "dhcp" ? "<container-ip>" : split("/", var.lxc_ip_address)[0]}:/root/vault-keys.txt .

    2. Store keys SECURELY (password manager or hardware security module)

    3. Delete keys from container:
       ssh root@${var.lxc_ip_address == "dhcp" ? "<container-ip>" : split("/", var.lxc_ip_address)[0]} 'shred -u /root/vault-keys.txt'

    4. Access Vault UI:
       ${var.lxc_ip_address == "dhcp" ? "http://<container-ip>:${var.vault_port}" : "http://${split("/", var.lxc_ip_address)[0]}:${var.vault_port}"}

    5. Unseal Vault using 3 of 5 unseal keys from vault-keys.txt

    6. Login with root token from vault-keys.txt

    📚 Next Configuration Steps:
    - Enable audit logging: vault audit enable file file_path=/var/log/vault/audit.log
    - Configure authentication methods (LDAP, OIDC, etc.)
    - Set up secret engines (KV, PKI, SSH, etc.)
    - Configure policies and access control
    - Set up TLS (recommended: use reverse proxy like Nginx)
    - Configure auto-unseal (AWS KMS, Transit, etc.)

    ${var.ansible_user_enabled ? <<-ANSIBLE_INFO

    🤖 Ansible User Information:
    - Username: ${var.ansible_user_name}
    - SSH Command: ssh ${var.ansible_user_name}@${var.lxc_ip_address == "dhcp" ? "<container-ip>" : split("/", var.lxc_ip_address)[0]}
    - Sudo Access: ${var.ansible_user_sudo ? "✅ Enabled (NOPASSWD)" : "❌ Disabled"}
    - Get inventory: tofu output -raw ansible_inventory_entry

    ANSIBLE_INFO
: ""}
    📖 Documentation: https://developer.hashicorp.com/vault/docs
  EOT
}

