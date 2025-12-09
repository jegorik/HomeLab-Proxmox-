# ╔════════════════════════════════════════════════════════════════════════════╗
# ║                     Fedora CoreOS VM - Outputs                             ║
# ║                                                                            ║
# ║  Output values for the provisioned Fedora CoreOS VM                        ║
# ║  Single-stage Cloud-Init deployment with Ignition                          ║
# ║                                                                            ║
# ║  Author: jegorik                                                           ║
# ║  Last Updated: December 2025                                               ║
# ╚════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# VM IDENTIFICATION OUTPUTS
# ==============================================================================

output "vm_id" {
  description = <<-EOT
    Proxmox VM ID (VMID) of the created Fedora CoreOS VM.
    Use this ID for Proxmox API operations and CLI commands.
  EOT
  value       = var.create_vm ? proxmox_virtual_environment_vm.fcos[0].vm_id : null
}

output "vm_name" {
  description = <<-EOT
    Name/hostname of the Fedora CoreOS VM.
    This is both the Proxmox display name and the OS hostname.
  EOT
  value       = var.create_vm ? proxmox_virtual_environment_vm.fcos[0].name : var.vm_name
}

output "vm_node" {
  description = <<-EOT
    Proxmox node where the VM is running.
    Useful for node-specific operations and migrations.
  EOT
  value       = var.create_vm ? proxmox_virtual_environment_vm.fcos[0].node_name : var.proxmox_node
}

# ==============================================================================
# NETWORK OUTPUTS
# ==============================================================================

output "vm_ipv4_addresses" {
  description = <<-EOT
    IPv4 addresses assigned to the VM.
    Requires QEMU guest agent to be installed and running.
    May take a few minutes to populate after VM creation.
  EOT
  value       = var.create_vm ? proxmox_virtual_environment_vm.fcos[0].ipv4_addresses : []
}

output "vm_ipv6_addresses" {
  description = <<-EOT
    IPv6 addresses assigned to the VM.
    Requires QEMU guest agent to be installed and running.
  EOT
  value       = var.create_vm ? proxmox_virtual_environment_vm.fcos[0].ipv6_addresses : []
}

output "vm_mac_addresses" {
  description = <<-EOT
    MAC addresses of the VM's network interfaces.
    Useful for DHCP reservations and network tracking.
  EOT
  value       = var.create_vm ? proxmox_virtual_environment_vm.fcos[0].mac_addresses : []
}

output "vm_primary_ip" {
  description = <<-EOT
    Primary IPv4 address of the VM (first non-loopback address).
    Convenience output for SSH connection.
    
    NOTE: This may be empty until the QEMU guest agent reports the IP.
    For immediate access, use the static IP if configured.
  EOT
  value = var.create_vm ? (
    length(proxmox_virtual_environment_vm.fcos[0].ipv4_addresses) > 0 ? (
      length([for ips in proxmox_virtual_environment_vm.fcos[0].ipv4_addresses : ips if length(ips) > 0]) > 0 ?
      flatten([for ips in proxmox_virtual_environment_vm.fcos[0].ipv4_addresses : ips if length(ips) > 0 && !startswith(ips[0], "127.")])[0] :
      (var.vm_ip_address != "" ? split("/", var.vm_ip_address)[0] : "pending")
    ) : (var.vm_ip_address != "" ? split("/", var.vm_ip_address)[0] : "pending")
  ) : null
}

# ==============================================================================
# SSH CONNECTION OUTPUTS
# ==============================================================================

output "ssh_connection_command" {
  description = <<-EOT
    SSH command to connect to the Fedora CoreOS VM.
    Uses the configured SSH user and primary IP address.
  EOT
  value = var.create_vm ? "ssh ${var.ssh_user}@${
    var.vm_ip_address != "" ? split("/", var.vm_ip_address)[0] :
    (length(proxmox_virtual_environment_vm.fcos[0].ipv4_addresses) > 0 ?
      flatten([for ips in proxmox_virtual_environment_vm.fcos[0].ipv4_addresses : ips if length(ips) > 0])[0] :
    "<pending-ip>")
  }" : null
}

output "ssh_user" {
  description = <<-EOT
    SSH username for connecting to the VM.
    This user has sudo privileges configured via Ignition.
  EOT
  value       = var.ssh_user
}

# ==============================================================================
# IGNITION CONFIGURATION OUTPUTS
# ==============================================================================

output "ignition_config_rendered" {
  description = <<-EOT
    The rendered Ignition JSON configuration.
    This is the actual configuration applied to the VM during first boot.
    
    SENSITIVE: May contain SSH keys and other configuration details.
    Useful for debugging Ignition issues.
  EOT
  value       = data.ct_config.vm_ignition.rendered
  sensitive   = true
}

output "ignition_config_hash" {
  description = <<-EOT
    SHA256 hash of the Ignition configuration.
    Useful for tracking configuration changes and versioning.
  EOT
  value       = sha256(data.ct_config.vm_ignition.rendered)
}

output "ignition_file_path" {
  description = <<-EOT
    Path to the generated Ignition JSON file on local machine.
    This file is also uploaded to Proxmox snippets storage.
  EOT
  value       = var.create_vm ? local_file.ignition_config[0].filename : null
}

output "ignition_file_location" {
  description = <<-EOT
    Location of Ignition config in Proxmox storage.
    Format: <storage>:snippets/<filename>
    
    The VM uses this via Cloud-Init vendor data.
  EOT
  value       = var.create_vm ? "${var.coreos_storage}:snippets/${local.ignition_snippet_name}" : null
}

# ==============================================================================
# IMAGE OUTPUTS
# ==============================================================================

output "fcos_image_filename" {
  description = <<-EOT
    Fedora CoreOS image filename used for VM creation.
  EOT
  value       = local.fcos_image_filename
}

output "fcos_image_path" {
  description = <<-EOT
    Path to the Fedora CoreOS image in Proxmox coreos storage.
    Format: /var/coreos/images/<filename>
  EOT
  value       = local.fcos_image_path
}

# ==============================================================================
# RESOURCE INFORMATION OUTPUTS
# ==============================================================================

output "vm_resources" {
  description = <<-EOT
    Summary of VM resource allocation.
    Useful for documentation and capacity planning.
  EOT
  value = {
    cpu_cores   = var.vm_cpu_cores
    cpu_sockets = var.vm_cpu_sockets
    cpu_type    = var.vm_cpu_type
    memory_mb   = var.vm_memory
    disk_size   = var.vm_disk_size
    storage     = var.vm_storage_pool
    network     = var.vm_network_bridge
  }
}

output "vm_status" {
  description = <<-EOT
    Current VM status information.
    Includes creation state and startup configuration.
  EOT
  value = {
    created     = var.create_vm
    started     = var.vm_started
    on_boot     = var.vm_on_boot
    protected   = var.vm_protection
    guest_agent = var.enable_qemu_guest_agent
  }
}

# ==============================================================================
# DEPLOYMENT METADATA
# ==============================================================================

output "deployment_info" {
  description = <<-EOT
    Deployment metadata for tracking and auditing.
    Useful for CI/CD pipeline integration and documentation.
  EOT
  value = {
    fcos_stream  = var.fcos_stream
    fcos_version = var.fcos_version
    proxmox_node = var.proxmox_node
    timezone     = var.timezone
    deployed_at  = timestamp()
  }
}

# ==============================================================================
# PROXMOX API OUTPUTS
# ==============================================================================

output "proxmox_vm_api_path" {
  description = <<-EOT
    Proxmox API path for this VM.
    Useful for direct API calls and integrations.
  EOT
  value       = var.create_vm ? "/nodes/${var.proxmox_node}/qemu/${proxmox_virtual_environment_vm.fcos[0].vm_id}" : null
}

# ==============================================================================
# DEPLOYMENT WORKFLOW SUMMARY
# ==============================================================================

output "deployment_workflow" {
  description = "Summary of the single-stage deployment workflow."
  value       = var.create_vm ? "VM ${var.vm_name} (ID: ${proxmox_virtual_environment_vm.fcos[0].vm_id}) deployed successfully with Ignition applied via Cloud-Init. ${var.vm_started ? "VM is starting - SSH access will be available shortly." : "VM is stopped - start it manually if needed."}" : null
}

# ==============================================================================
# END OF OUTPUTS
# ==============================================================================
