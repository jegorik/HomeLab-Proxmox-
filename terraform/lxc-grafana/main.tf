# =============================================================================
# Main Configuration - LXC Grafana Container
# =============================================================================
#
# This file defines the main resources for deploying a Grafana monitoring
# dashboard in an LXC container on Proxmox VE.
#
# Resources Created:
#   1. random_password.root_password     - Container root password
#   2. random_password.grafana_password  - Grafana admin password
#   3. proxmox_virtual_environment_container.grafana - LXC container
#
# Architecture:
#   - Unprivileged LXC container (security best practice)
#   - Ubuntu 24.04 LTS base image
#   - Grafana OSS installed via official APT repository
#   - Systemd service for Grafana
#
# Security Features:
#   - Unprivileged container execution
#   - SSH key authentication
#   - Generated strong passwords
#   - Minimal resource allocation
#   - No anonymous access by default
#
# Post-Deployment:
#   - Access Grafana at http://<container-ip>:3000
#   - Default admin user configured via variables
#   - Add data sources (Prometheus, InfluxDB, etc.)
#
# Requirements:
#   - LXC template must exist on Proxmox storage
#   - Network bridge must be configured
#   - API token with sufficient permissions
#
# Author: HomeLab Infrastructure
# Provider: bpg/proxmox v0.88.0
# Last Updated: December 2025
# =============================================================================

# -----------------------------------------------------------------------------
# Local Values
# -----------------------------------------------------------------------------

locals {
  # Use provided password or generated one
  root_password    = var.lxc_root_password != "" ? var.lxc_root_password : random_password.root_password.result
  grafana_password = var.grafana_admin_password != "" ? var.grafana_admin_password : random_password.grafana_password.result

  # Container tags as comma-separated string
  tags = join(",", var.lxc_tags)

  # Network configuration
  ip_config = var.lxc_ip_address == "dhcp" ? "ip=dhcp" : "ip=${var.lxc_ip_address},gw=${var.lxc_gateway}"
}

# -----------------------------------------------------------------------------
# Password Generation
# -----------------------------------------------------------------------------

# Generate root password if not provided
resource "random_password" "root_password" {
  length           = var.password_length
  special          = true
  override_special = var.password_special_chars
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 1
}

# Generate Grafana admin password if not provided
resource "random_password" "grafana_password" {
  length           = var.password_length
  special          = true
  override_special = var.password_special_chars
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 1
}

# -----------------------------------------------------------------------------
# LXC Container Resource
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_container" "grafana" {
  # Basic identification
  description = var.lxc_description
  node_name   = var.proxmox_node
  vm_id       = var.lxc_id
  tags        = var.lxc_tags

  # Lifecycle settings
  start_on_boot = var.lxc_start_on_boot
  started       = true
  unprivileged  = var.lxc_unprivileged
  protection    = var.lxc_protection

  # Container features
  features {
    nesting = var.lxc_nesting # Required for systemd
  }

  # Operating system template
  operating_system {
    template_file_id = "${var.lxc_template_storage}:vztmpl/${var.lxc_template_file}"
    type             = "ubuntu"
  }

  # Root filesystem
  disk {
    datastore_id = var.lxc_disk_storage
    size         = var.lxc_disk_size
  }

  # CPU allocation
  cpu {
    cores = var.lxc_cpu_cores
  }

  # Memory allocation
  memory {
    dedicated = var.lxc_memory
    swap      = var.lxc_swap
  }

  # Network configuration
  network_interface {
    name   = "eth0"
    bridge = var.lxc_network_bridge
  }

  # Initialization settings
  initialization {
    hostname = var.lxc_hostname

    # IP configuration
    ip_config {
      ipv4 {
        address = var.lxc_ip_address == "dhcp" ? "dhcp" : var.lxc_ip_address
        gateway = var.lxc_ip_address == "dhcp" ? null : var.lxc_gateway
      }
    }

    # DNS configuration
    dns {
      servers = split(" ", var.lxc_dns_servers)
    }

    # User account configuration
    user_account {
      password = local.root_password
      keys     = [trimspace(file(pathexpand(var.ssh_public_key_path)))]
    }
  }

  # Startup/shutdown behavior
  startup {
    order      = "2"
    up_delay   = "30"
    down_delay = "30"
  }

  # Prevent unnecessary recreation
  lifecycle {
    ignore_changes = [
      initialization[0].user_account[0].password,
      initialization[0].user_account[0].keys,
    ]
  }
}

# -----------------------------------------------------------------------------
# Grafana Installation (via terraform_data for idempotency)
# -----------------------------------------------------------------------------

resource "terraform_data" "grafana_install" {
  # Trigger reinstall when these change
  triggers_replace = [
    var.grafana_version,
    proxmox_virtual_environment_container.grafana.id,
  ]

  # Wait for container to be ready
  depends_on = [proxmox_virtual_environment_container.grafana]

  # Execute installation script
  provisioner "remote-exec" {
    inline = [
      # Wait for container to fully start and network to be ready
      "sleep 15",

      # Update package lists
      "apt-get update -qq",

      # Install prerequisites
      "apt-get install -y -qq apt-transport-https software-properties-common wget gnupg2",

      # Add Grafana GPG key
      "mkdir -p /etc/apt/keyrings",
      "wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor > /etc/apt/keyrings/grafana.gpg",

      # Add Grafana repository
      "echo 'deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main' > /etc/apt/sources.list.d/grafana.list",

      # Install Grafana
      "apt-get update -qq",
      var.grafana_version == "latest" ? "apt-get install -y -qq grafana" : "apt-get install -y -qq grafana=${var.grafana_version}",

      # Security hardening in grafana.ini
      "sed -i 's/;disable_gravatar = false/disable_gravatar = true/' /etc/grafana/grafana.ini",
      "sed -i 's/;cookie_secure = false/cookie_secure = false/' /etc/grafana/grafana.ini",
      var.grafana_allow_anonymous ? "sed -i 's/;enabled = false/enabled = true/' /etc/grafana/grafana.ini" : "echo 'Anonymous access disabled'",

      # Set Grafana port
      "sed -i 's/;http_port = 3000/http_port = ${var.grafana_port}/' /etc/grafana/grafana.ini",

      # Enable and start Grafana service
      "systemctl daemon-reload",
      "systemctl enable grafana-server",
      "systemctl start grafana-server",

      # Wait for Grafana to fully initialize (creates database)
      "sleep 10",

      # Verify service is running
      "systemctl is-active grafana-server",
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(pathexpand(replace(var.ssh_public_key_path, ".pub", "")))
      host        = split("/", var.lxc_ip_address)[0]
    }
  }
}

# -----------------------------------------------------------------------------
# Grafana Admin Password Configuration
# -----------------------------------------------------------------------------
# Note: Password must be set AFTER Grafana starts and creates its database.
# Using grafana-cli ensures the password is properly hashed in the SQLite DB.

resource "terraform_data" "grafana_password" {
  # Trigger password reset when password changes
  triggers_replace = [
    local.grafana_password,
    var.grafana_admin_user,
  ]

  # Must run after Grafana is installed and running
  depends_on = [terraform_data.grafana_install]

  # Set admin password using grafana-cli
  provisioner "remote-exec" {
    inline = [
      # Wait for Grafana to be fully ready
      "sleep 5",

      # Reset admin password using grafana-cli (proper way)
      "grafana-cli admin reset-admin-password '${local.grafana_password}'",

      # Restart Grafana to apply any config changes
      "systemctl restart grafana-server",

      # Verify service is running
      "sleep 3",
      "systemctl is-active grafana-server",
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(pathexpand(replace(var.ssh_public_key_path, ".pub", "")))
      host        = split("/", var.lxc_ip_address)[0]
    }
  }
}
