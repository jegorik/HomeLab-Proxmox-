#cloud-config
# ============================================================================
# openSUSE Leap 15.6 Cloud-Init User Configuration
# ============================================================================
# This template configures:
# - Ansible automation service account (wheel group, passwordless sudo)
# - Administrative user (wheel group, password-required sudo)
# - SSH key authentication for both users
# - System hardening (disable root login, disable password auth)
# - Essential package installation
# - System services configuration
# ============================================================================

# Basic system configuration
hostname: ${hostname}
timezone: UTC
locale: en_US.UTF-8

# ============================================================================
# SSH Server Hardening
# ============================================================================
ssh_pwauth: false
disable_root: true

# ============================================================================
# User Account Configuration
# ============================================================================
users:
  # Keep default 'opensuse' user from cloud image
  - default

  # ========================================================================
  # Ansible Automation Service Account
  # ========================================================================
  # This user is for automated provisioning and management via Ansible
  # - No password login (SSH key only)
  # - Passwordless sudo for automation scripts
  # - Added to wheel group (sudoers)
  - name: ansible
    gecos: "Ansible Automation Service Account"
    groups: [wheel]
    shell: /bin/bash
    ssh_authorized_keys:
      - ${ansible_ssh_key}
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
    system: false
    selinux_user: unconfined_u
    homedir: /home/ansible

  # ========================================================================
  # Administrative User Account
  # ========================================================================
  # This user is for system administration and maintenance
  # - Password login disabled (SSH key only)
  # - Password-required sudo (for security-sensitive operations)
  # - Added to wheel and docker groups
  - name: ${admin_username}
    gecos: "System Administrator"
    groups: [wheel, docker, libvirt, kvm]
    shell: /bin/bash
    ssh_authorized_keys:
      - ${admin_ssh_key}
    sudo: ALL=(ALL) ALL
    lock_passwd: false
    system: false
    selinux_user: unconfined_u
    homedir: /home/${admin_username}

# ============================================================================
# Package Management
# ============================================================================
package_update: true
package_upgrade: true

packages:
  # System monitoring and management
  - qemu-guest-agent
  - systemd-container
  - curl
  - wget
  - git
  - htop
  - net-tools
  - vim
  - nano
  - tmux
  - openssh-clients
  
  # Python for Ansible compatibility
  - python3
  - python3-pip
  - python3-devel
  
  # Development tools
  - build-essential
  - gcc
  - make
  
  # Utilities
  - sudo
  - dbus-daemon
  - ca-certificates

# ============================================================================
# SSH Configuration Hardening
# ============================================================================
runcmd:
  # Enable and start QEMU guest agent for Proxmox integration
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  
  # SSH server hardening
  - sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  - sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  - sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
  - echo "X11Forwarding no" >> /etc/ssh/sshd_config
  - echo "X11UseLocalhost yes" >> /etc/ssh/sshd_config
  - echo "PermitUserEnvironment no" >> /etc/ssh/sshd_config
  - echo "Ciphers chacha20-poly1305@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr" >> /etc/ssh/sshd_config
  - echo "MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256,hmac-sha2-512" >> /etc/ssh/sshd_config
  - systemctl reload sshd
  
  # Configure firewall
  - systemctl enable firewalld
  - firewall-cmd --permanent --add-service=ssh
  - firewall-cmd --permanent --set-default-zone=public
  - firewall-cmd --reload
  
  # Create system log entry
  - echo "Cloud-init provisioning completed at $(date)" | tee /var/log/cloud-init-done.log
  - logger -t cloud-init "VM provisioning completed successfully"
  - systemctl status qemu-guest-agent >> /var/log/cloud-init-done.log

# ============================================================================
# Final Status Message
# ============================================================================
final_message: "openSUSE Leap 15.6 VM provisioned successfully in $UPTIME seconds"
