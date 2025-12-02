# =============================================================================
# Outputs - Ubuntu VM Deployment
# =============================================================================
# 
# This file defines the output values exposed after Terraform applies the
# infrastructure configuration. Outputs provide important information about
# the created resources.
#
# Security Note: The VM password is marked as sensitive and will not be
# displayed in CLI output. Use `terraform output -raw ubuntu_vm_password`
# to retrieve it when needed.
#
# Usage:
#   terraform output                          # Show all non-sensitive outputs
#   terraform output -raw ubuntu_vm_password  # Get the VM password
#   terraform output -json ubuntu_vm_ip       # Get IP addresses as JSON
#
# Author: HomeLab Infrastructure
# Last Updated: December 2025
# =============================================================================

# -----------------------------------------------------------------------------
# Authentication Outputs
# -----------------------------------------------------------------------------

output "ubuntu_vm_password" {
  description = "Generated password for the Ubuntu VM user account"
  value       = random_password.ubuntu_vm_password.result
  sensitive   = true
}

output "ubuntu_vm_ssh_key_path" {
  description = "Path to SSH public key used for VM access"
  value       = var.ssh_key_path
}

# -----------------------------------------------------------------------------
# Network Outputs
# -----------------------------------------------------------------------------

output "ubuntu_vm_ip" {
  description = "IPv4 addresses assigned to the VM (requires QEMU Guest Agent)"
  value       = proxmox_virtual_environment_vm.ubuntu_vm.ipv4_addresses
}