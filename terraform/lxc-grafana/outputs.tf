# =============================================================================
# Outputs - LXC Grafana Container
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
#   tofu output -raw grafana_admin_password  # Get Grafana admin password
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
  value       = proxmox_virtual_environment_container.grafana.vm_id
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

output "grafana_url" {
  description = "Grafana web interface URL"
  value       = var.lxc_ip_address == "dhcp" ? "http://<container-ip>:${var.grafana_port}" : "http://${split("/", var.lxc_ip_address)[0]}:${var.grafana_port}"
}

# -----------------------------------------------------------------------------
# Authentication Credentials
# -----------------------------------------------------------------------------

output "lxc_root_password" {
  description = "Container root password"
  value       = local.root_password
  sensitive   = true
}

output "grafana_admin_user" {
  description = "Grafana admin username"
  value       = var.grafana_admin_user
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = local.grafana_password
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
