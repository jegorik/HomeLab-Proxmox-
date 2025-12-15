# =============================================================================
# OpenSUSE Leap 16 VM Outputs
# =============================================================================
# This file defines output values that are displayed after successful
# deployment and can be referenced by other Terraform/OpenTofu configurations.
# =============================================================================

# -----------------------------------------------------------------------------
# VM Identity Outputs
# -----------------------------------------------------------------------------

output "vm_id" {
  description = "The ID of the created virtual machine"
  value       = proxmox_virtual_environment_vm.opensuseLeap16.vm_id
}

output "vm_name" {
  description = "The name of the virtual machine"
  value       = proxmox_virtual_environment_vm.opensuseLeap16.name
}

output "vm_node" {
  description = "The Proxmox node hosting the VM"
  value       = proxmox_virtual_environment_vm.opensuseLeap16.node_name
}

output "vm_tags" {
  description = "Tags assigned to the VM"
  value       = proxmox_virtual_environment_vm.opensuseLeap16.tags
}

# -----------------------------------------------------------------------------
# VM Network Information
# -----------------------------------------------------------------------------

output "vm_ipv4_addresses" {
  description = "IPv4 addresses assigned to the VM"
  value       = proxmox_virtual_environment_vm.opensuseLeap16.ipv4_addresses
  sensitive   = true  # Contains potentially sensitive network information
}

output "vm_ipv6_addresses" {
  description = "IPv6 addresses assigned to the VM"
  value       = proxmox_virtual_environment_vm.opensuseLeap16.ipv6_addresses
  sensitive   = true  # Contains potentially sensitive network information
}

output "vm_mac_addresses" {
  description = "MAC addresses of VM network interfaces"
  value       = proxmox_virtual_environment_vm.opensuseLeap16.mac_addresses
  sensitive   = true  # MAC addresses should not be displayed in logs
}

output "vm_network_interface_names" {
  description = "Network interface names in the guest OS"
  value       = proxmox_virtual_environment_vm.opensuseLeap16.network_interface_names
}

# -----------------------------------------------------------------------------
# VM Hardware Configuration
# -----------------------------------------------------------------------------

output "vm_cpu_cores" {
  description = "Number of CPU cores allocated"
  value       = proxmox_virtual_environment_vm.opensuseLeap16.cpu[0].cores
}

output "vm_memory_dedicated" {
  description = "Dedicated memory in MB"
  value       = proxmox_virtual_environment_vm.opensuseLeap16.memory[0].dedicated
}

output "vm_memory_floating" {
  description = "Floating memory (balloon) in MB"
  value       = proxmox_virtual_environment_vm.opensuseLeap16.memory[0].floating
}

# -----------------------------------------------------------------------------
# VM Status Information
# -----------------------------------------------------------------------------

output "vm_started" {
  description = "Whether the VM is currently running"
  value       = proxmox_virtual_environment_vm.opensuseLeap16.started
}

output "vm_template" {
  description = "Whether this is a template"
  value       = proxmox_virtual_environment_vm.opensuseLeap16.template
}

# -----------------------------------------------------------------------------
# PCI Passthrough Information
# -----------------------------------------------------------------------------

output "vm_gpu_pci_id" {
  description = "GPU PCI device ID passed through to VM"
  value       = var.vm_hostpci0_id
}

output "vm_audio_pci_id" {
  description = "Audio controller PCI device ID passed through to VM"
  value       = var.vm_hostpci4_id
}

# -----------------------------------------------------------------------------
# Connection Information Summary
# -----------------------------------------------------------------------------

output "connection_info" {
  description = "Summary of VM connection information"
  value = {
    vm_id  = proxmox_virtual_environment_vm.opensuseLeap16.vm_id
    name   = proxmox_virtual_environment_vm.opensuseLeap16.name
    node   = proxmox_virtual_environment_vm.opensuseLeap16.node_name
    ipv4   = try(proxmox_virtual_environment_vm.opensuseLeap16.ipv4_addresses[1][0], "No IP assigned")
    status = proxmox_virtual_environment_vm.opensuseLeap16.started ? "running" : "stopped"
    gpu    = var.vm_hostpci0_id
    agent  = var.qemu_agent_enabled ? "enabled" : "disabled"
  }
  sensitive = true  # Contains network addresses and VM configuration details
}

