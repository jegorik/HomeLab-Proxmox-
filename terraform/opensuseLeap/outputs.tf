# =============================================================================
# OpenSUSE Leap 15.6 VM Outputs
# =============================================================================
# This file defines output values that are displayed after successful
# deployment and can be referenced by other Terraform/OpenTofu configurations.
#
# Output Categories:
# 1. VM Identity: ID, name, node, tags
# 2. Network Information: IP addresses, MAC addresses, interfaces
# 3. Hardware Configuration: CPU, memory allocation
# 4. VM Status: Running state, template flag
# 5. PCI Passthrough: GPU and audio device IDs
# 6. Connection Summary: Consolidated information for quick access
#
# Usage Examples:
#
# Display all outputs:
#   tofu output
#
# Get specific output value:
#   tofu output vm_id
#   tofu output vm_ipv4_addresses
#
# Use output in another module:
#   module.opensuse_vm.vm_id
#   module.opensuse_vm.connection_info
#
# Export output to file:
#   tofu output -json > vm_outputs.json
#
# Get SSH connection string (if IP is available):
#   ssh admin@$(tofu output -raw vm_ipv4_addresses | jq -r '.[1][0]')
#
# Sensitive Outputs:
# - Network addresses are marked sensitive to prevent logging
# - Use -raw flag to display: tofu output -raw vm_ipv4_addresses
# - Sensitive outputs are hidden in plan/apply output by default
# =============================================================================

# -----------------------------------------------------------------------------
# VM Identity Outputs
# -----------------------------------------------------------------------------

output "vm_id" {
  description = "The ID of the created virtual machine"
  value       = try(proxmox_virtual_environment_vm.opensuseLeap[0].vm_id, null)
}

output "vm_name" {
  description = "The name of the virtual machine"
  value       = try(proxmox_virtual_environment_vm.opensuseLeap[0].name, null)
}

output "vm_node" {
  description = "The Proxmox node hosting the VM"
  value       = try(proxmox_virtual_environment_vm.opensuseLeap[0].node_name, null)
}

output "vm_tags" {
  description = "Tags assigned to the VM"
  value       = try(proxmox_virtual_environment_vm.opensuseLeap[0].tags, null)
}

# -----------------------------------------------------------------------------
# VM Network Information
# -----------------------------------------------------------------------------

output "vm_ipv4_addresses" {
  description = "IPv4 addresses assigned to the VM"
  value       = try(proxmox_virtual_environment_vm.opensuseLeap[0].ipv4_addresses, [])
  sensitive   = true # Contains potentially sensitive network information
}

output "vm_ipv6_addresses" {
  description = "IPv6 addresses assigned to the VM"
  value       = try(proxmox_virtual_environment_vm.opensuseLeap[0].ipv6_addresses, [])
  sensitive   = true # Contains potentially sensitive network information
}

output "vm_mac_addresses" {
  description = "MAC addresses of VM network interfaces"
  value       = try(proxmox_virtual_environment_vm.opensuseLeap[0].mac_addresses, [])
  sensitive   = true # MAC addresses should not be displayed in logs
}

output "vm_network_interface_names" {
  description = "Network interface names in the guest OS"
  value       = try(proxmox_virtual_environment_vm.opensuseLeap[0].network_interface_names, [])
}

# -----------------------------------------------------------------------------
# VM Hardware Configuration
# -----------------------------------------------------------------------------

output "vm_cpu_cores" {
  description = "Number of CPU cores allocated"
  value       = try(proxmox_virtual_environment_vm.opensuseLeap[0].cpu[0].cores, null)
}

output "vm_memory_dedicated" {
  description = "Dedicated memory in MB"
  value       = try(proxmox_virtual_environment_vm.opensuseLeap[0].memory[0].dedicated, null)
}

output "vm_memory_floating" {
  description = "Floating memory (balloon) in MB"
  value       = try(proxmox_virtual_environment_vm.opensuseLeap[0].memory[0].floating, null)
}

# -----------------------------------------------------------------------------
# VM Status Information
# -----------------------------------------------------------------------------

output "vm_started" {
  description = "Whether the VM is currently running"
  value       = try(proxmox_virtual_environment_vm.opensuseLeap[0].started, null)
}

output "vm_template" {
  description = "Whether this is a template"
  value       = try(proxmox_virtual_environment_vm.opensuseLeap[0].template, null)
}

# -----------------------------------------------------------------------------
# PCI Passthrough Information
# -----------------------------------------------------------------------------
# Outputs for GPU and audio device passthrough configuration
# Useful for documentation and verification of hardware assignments
#
# Usage:
#   tofu output vm_gpu_pci_id    # Display GPU device ID
#   tofu output vm_audio_pci_id  # Display audio device ID

output "vm_gpu_pci_id" {
  description = "GPU PCI device ID passed through to VM (format: 0000:BB:DD.F)"
  value       = var.vm_hostpci0_id
}

output "vm_audio_pci_id" {
  description = "Audio controller PCI device ID passed through to VM (format: 0000:BB:DD.F)"
  value       = var.vm_hostpci4_id
}

# -----------------------------------------------------------------------------
# Connection Information Summary
# -----------------------------------------------------------------------------
# Consolidated output containing all essential VM connection and status info
# This is the most useful output for quick reference after deployment
#
# Fields Included:
# - vm_id: Proxmox VM identifier (for GUI access and CLI commands)
# - name: VM name as shown in Proxmox
# - node: Proxmox node hosting the VM
# - ipv4: Primary IPv4 address (from QEMU guest agent)
# - status: Current VM state (running/stopped)
# - gpu: Passed-through GPU device ID
# - agent: QEMU guest agent status
#
# Usage Examples:
#   tofu output connection_info           # Display as table
#   tofu output -json connection_info     # Export as JSON
#
# SSH Connection (after cloud-init completes):
#   IP=$(tofu output -json connection_info | jq -r '.ipv4')
#   ssh admin@$IP -i ~/.ssh/admin_key
#   ssh ansible@$IP -i ~/.ssh/ansible_key
#
# Proxmox Console Access:
#   https://<proxmox-ip>:8006/?console=kvm&novnc=1&vmid=<vm_id>
#
# Note: IP address requires QEMU guest agent to be running in the VM
# If "No IP assigned" appears, wait for cloud-init to complete or check agent status

output "connection_info" {
  description = "Consolidated VM connection information for quick access"
  value = try({
    vm_id  = proxmox_virtual_environment_vm.opensuseLeap[0].vm_id
    name   = proxmox_virtual_environment_vm.opensuseLeap[0].name
    node   = proxmox_virtual_environment_vm.opensuseLeap[0].node_name
    ipv4   = try(proxmox_virtual_environment_vm.opensuseLeap[0].ipv4_addresses[1][0], "No IP assigned - QEMU agent may not be running yet")
    status = proxmox_virtual_environment_vm.opensuseLeap[0].started ? "running" : "stopped"
    gpu    = var.vm_hostpci0_id
    agent  = var.qemu_agent_enabled ? "enabled" : "disabled"
  }, null)
  sensitive = true # Contains network addresses and VM configuration details
}

