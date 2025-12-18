# =============================================================================
# HashiCorp Vault LXC Container - Infrastructure as Code
# =============================================================================
#
# This Terraform configuration deploys a HashiCorp Vault instance in a
# Proxmox LXC container with automated installation and initialization.
#
# Components:
# - LXC container with Debian base
# - HashiCorp Vault installation via official repository
# - Systemd service configuration
# - File-based storage backend
# - HTTP listener (TLS disabled - should be fronted by reverse proxy)
#
# Security Considerations:
# - Container runs unprivileged by default
# - Vault runs as dedicated system user
# - Root password is randomly generated if not provided
# - SSH key-based authentication enforced
# - State file encryption enabled (see encryption.tf)
#
# Post-Deployment:
# 1. Retrieve initialization keys from container: /root/vault-keys.txt
# 2. Store unseal keys and root token securely (use a password manager)
# 3. Configure TLS (recommended: use reverse proxy like Nginx)
# 4. Enable audit logging
# 5. Configure authentication methods
#
# Author: HomeLab Infrastructure
# Last Updated: December 2025
# =============================================================================

# -----------------------------------------------------------------------------
# Local Values
# -----------------------------------------------------------------------------

locals {
  # Use provided password or generated one
  root_password = var.lxc_root_password != "" ? var.lxc_root_password : random_password.root_password.result

  # Container tags as comma-separated string
  tags = join(",", var.lxc_tags)

  # Extract IP address without CIDR notation for SSH connection
  container_ip = var.lxc_ip_address == "dhcp" ? "" : split("/", var.lxc_ip_address)[0]
}

# -----------------------------------------------------------------------------
# Password Generation
# -----------------------------------------------------------------------------

# Generate secure root password if not provided via variable
# Password will be stored in encrypted state file and can be retrieved
# using: tofu output -raw lxc_root_password
resource "random_password" "root_password" {
  length           = var.password_length
  special          = true
  override_special = var.password_special_chars
  min_lower        = var.password_lower_chars_count
  min_upper        = var.password_upper_chars_count
  min_numeric      = var.password_upper_numeric_count
  min_special      = var.password_upper_special_chars_count
}

# Password lifecycle: Generate once and don't rotate on every apply
# This prevents breaking SSH access during infrastructure updates
resource "terraform_data" "password_keeper" {
  input = random_password.root_password.result
}

# -----------------------------------------------------------------------------
# LXC Container Resource
# -----------------------------------------------------------------------------

# Create Proxmox LXC container for HashiCorp Vault
# This container will host the Vault service with file-based storage backend
resource "proxmox_virtual_environment_container" "vault" {
  # Basic identification
  description = var.lxc_description
  node_name   = var.proxmox_node
  vm_id       = var.lxc_id
  tags        = var.lxc_tags

  # Lifecycle settings
  start_on_boot = var.lxc_start_on_boot
  started       = true
  unprivileged  = var.lxc_unprivileged # Run unprivileged for security
  protection    = var.lxc_protection   # Prevent accidental deletion

  # Container features
  features {
    nesting = var.lxc_nesting # Required for systemd and proper service management
  }

  # Operating system template
  operating_system {
    template_file_id = "${var.lxc_template_storage}:vztmpl/${var.lxc_template_file}"
    type             = var.lxc_os_type
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
    name   = var.lxc_network_interface_name
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
    order      = var.lxc_startup_order
    up_delay   = var.lxc_up_delay
    down_delay = var.lxc_down_delay
  }

  # Prevent unnecessary recreation when password or SSH keys change
  # This ensures container stability during state refreshes
  lifecycle {
    ignore_changes = [
      initialization,
    ]
  }
}

# -----------------------------------------------------------------------------
# Vault Installation and Configuration
# -----------------------------------------------------------------------------

# Install and configure HashiCorp Vault via remote-exec provisioner
# This resource uses terraform_data for better lifecycle management
# and idempotency compared to null_resource
resource "terraform_data" "vault_install" {
  # Trigger reinstall only when container is recreated
  triggers_replace = [
    proxmox_virtual_environment_container.vault.id,
  ]

  # Ensure container is fully created before attempting installation
  depends_on = [proxmox_virtual_environment_container.vault]

  # Execute installation script via SSH
  provisioner "remote-exec" {
    inline = [<<-EOT
      #!/bin/bash
      set -e  # Exit on any error



      echo "=== Starting HashiCorp Vault Installation ==="

      # Wait for container to fully boot and network to be ready
      echo "Waiting for system to be ready..."
      sleep 15

      # Update package repository
      echo "Updating package lists..."
      apt-get update -qq

      # Install prerequisites
      echo "Installing prerequisites..."
      apt-get install -y -qq wget gpg curl unzip lsb-release ca-certificates sudo

      # Add HashiCorp GPG key
      echo "Adding HashiCorp repository..."
      mkdir -p /usr/share/keyrings
      wget -qO- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

      # Add HashiCorp repository
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list

      # Install Vault
      echo "Installing HashiCorp Vault..."
      apt-get update -qq
      apt-get install -y -qq vault

      # Create Vault system user and directories
      echo "Creating Vault user and directories..."
      if ! id -u vault > /dev/null 2>&1; then
        useradd --system --home /etc/vault.d --shell /bin/false vault
      fi
      mkdir -p /var/lib/vault/data
      mkdir -p /etc/vault.d
      chown -R vault:vault /var/lib/vault /etc/vault.d
      chmod 755 /var/lib/vault
      chmod 750 /etc/vault.d

      # Create Vault configuration file
      echo "Creating Vault configuration..."
      cat > /etc/vault.d/vault.hcl <<'CONFIG_EOF'
# HashiCorp Vault Configuration
# Auto-generated by Terraform

# Enable Web UI
ui = true

# Disable mlock to prevent memory from being swapped to disk
# IMPORTANT: Set to 'true' for LXC containers (CAP_IPC_LOCK not available)
# In production VMs with proper capabilities, this can be set to 'false'
disable_mlock = true

# Storage backend - File-based (not recommended for production)
# For production, consider Consul, etcd, or cloud storage backends
storage "file" {
  path = "/var/lib/vault/data"
}

# HTTP listener
# WARNING: TLS is disabled. Use a reverse proxy with TLS in production
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

# API address for cluster communication
api_addr = "http://0.0.0.0:8200"
CONFIG_EOF

      chown vault:vault /etc/vault.d/vault.hcl
      chmod 640 /etc/vault.d/vault.hcl

      # Create systemd service file
      echo "Creating systemd service..."
      cat > /etc/systemd/system/vault.service <<'SERVICE_EOF'
[Unit]
Description=HashiCorp Vault - A tool for managing secrets
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault.d/vault.hcl
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=notify
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
NoNewPrivileges=yes
ExecStart=/usr/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
LimitNOFILE=65536
# Note: LimitMEMLOCK removed as disable_mlock=true in vault.hcl

[Install]
WantedBy=multi-user.target
SERVICE_EOF

      # Enable and start Vault service
      echo "Starting Vault service..."
      systemctl daemon-reload
      systemctl enable vault
      systemctl start vault

      # Wait for Vault to be ready
      echo "Waiting for Vault to start..."
      sleep 5

      # Initialize Vault and save keys securely
      echo "Initializing Vault..."
      export VAULT_ADDR='http://127.0.0.1:8200'

      # Initialize and save output to secure file
      vault operator init > /root/vault-keys.txt
      chmod 600 /root/vault-keys.txt

      ${var.ansible_user_enabled ? <<-ANSIBLE_USER
      echo ""
      echo "=== Creating Ansible User ==="

      # Create Ansible user if it doesn't exist
      if ! id -u ${var.ansible_user_name} > /dev/null 2>&1; then
        useradd -m -s ${var.ansible_user_shell} ${var.ansible_user_name}
        echo "User '${var.ansible_user_name}' created successfully"
      else
        echo "User '${var.ansible_user_name}' already exists"
      fi

      # Create .ssh directory and set permissions
      mkdir -p /home/${var.ansible_user_name}/.ssh
      chmod 700 /home/${var.ansible_user_name}/.ssh

      # Add SSH public key
      cat > /home/${var.ansible_user_name}/.ssh/authorized_keys <<'ANSIBLE_KEY_EOF'
      ${trimspace(file(pathexpand(var.ansible_ssh_public_key_path)))}
      ANSIBLE_KEY_EOF

      chmod 600 /home/${var.ansible_user_name}/.ssh/authorized_keys
      chown -R ${var.ansible_user_name}:${var.ansible_user_name} /home/${var.ansible_user_name}/.ssh

      # Configure sudo access
      ${var.ansible_user_sudo ? <<-SUDO_CONFIG
      # Add user to sudo group
      usermod -aG sudo ${var.ansible_user_name}

      # Ensure sudoers.d directory exists
      mkdir -p /etc/sudoers.d

      # Configure sudoers
      ${length(var.ansible_user_sudo_commands) > 0 ? <<-LIMITED_SUDO
      # Limited sudo commands
      cat > /etc/sudoers.d/${var.ansible_user_name} <<'SUDOERS_EOF'
      # Ansible user sudo configuration - managed by Terraform
      ${var.ansible_user_name} ALL=(ALL) NOPASSWD: ${join(", ", var.ansible_user_sudo_commands)}
      SUDOERS_EOF
      LIMITED_SUDO
      : <<-FULL_SUDO
      # Full sudo access without password
      cat > /etc/sudoers.d/${var.ansible_user_name} <<'SUDOERS_EOF'
      # Ansible user sudo configuration - managed by Terraform
      ${var.ansible_user_name} ALL=(ALL) NOPASSWD:ALL
      SUDOERS_EOF
      FULL_SUDO
    }

      chmod 440 /etc/sudoers.d/${var.ansible_user_name}

      # Validate sudoers file
      visudo -c -f /etc/sudoers.d/${var.ansible_user_name}
      SUDO_CONFIG
  : "# Sudo access not enabled for Ansible user"}

      # Add to additional groups
      ${length(var.ansible_user_groups) > 0 ? "usermod -aG ${join(",", var.ansible_user_groups)} ${var.ansible_user_name}" : "# No additional groups configured"}

      echo "Ansible user '${var.ansible_user_name}' configured successfully"
      echo "SSH access: ssh ${var.ansible_user_name}@${local.container_ip}"
      ANSIBLE_USER
  : "# Ansible user creation disabled"}

      echo ""
      echo "=== Vault Installation Complete ==="
      echo "IMPORTANT: Initialization keys saved to /root/vault-keys.txt"
      echo "Please retrieve this file immediately and store securely!"
      echo "Command: scp root@${local.container_ip}:/root/vault-keys.txt ."
      echo ""
      echo "After securing keys, delete the file from the server:"
      echo "Command: ssh root@${local.container_ip} 'shred -u /root/vault-keys.txt'"
      ${var.ansible_user_enabled ? <<-ANSIBLE_MSG
      echo ""
      echo "=== Ansible User Created ==="
      echo "Username: ${var.ansible_user_name}"
      echo "SSH Command: ssh ${var.ansible_user_name}@${local.container_ip}"
      echo "Sudo Access: ${var.ansible_user_sudo ? "Enabled (NOPASSWD)" : "Disabled"}"
      ANSIBLE_MSG
: ""}
      EOT
]

# SSH connection configuration
connection {
  type        = "ssh"
  user        = "root"
  private_key = file(pathexpand(replace(var.ssh_public_key_path, ".pub", "")))
  host        = local.container_ip
  timeout     = "5m"
}
}
}

