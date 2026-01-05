# HomeLab (Proxmox) configuration collection

This repository is a curated collection of configuration files and deployment
templates for a Proxmox-based home laboratory. Its purpose is to gather
reliable, reusable examples (Docker Compose, container templates, environment
files, and Terraform/OpenTofu IaC) that simplify deploying services in a homelab
environment managed by Proxmox and/or Docker.

The repository is maintained as a living document: new configurations and
templates will be added over time. Use the links below to navigate to folder
examples and find concise guidance for each component.

## Directories

### Docker Compose Services

- [`docker-compose/`](docker-compose/) — Docker Compose examples and templates.
  - [`checkmk/`](docker-compose/checkmk/) — Checkmk Raw Edition for infrastructure monitoring.
  - [`homeassistant/`](docker-compose/homeassistant/) — Home Assistant Container for home automation.
  - [`nextcloud(aio)/`](docker-compose/nextcloud(aio)/) — Nextcloud All-In-One (AIO) file sync and collaboration.
  - [`nginx-proxy-manager/`](docker-compose/nginx-proxy-manager/) — Nginx Proxy Manager for reverse proxy with Let's Encrypt.
  - [`prometheus-grafana/`](docker-compose/prometheus-grafana/) — Prometheus + Grafana monitoring stack with Node Exporter.
  - [`wazuh/`](docker-compose/wazuh/) — Wazuh SIEM/XDR for security monitoring and threat detection.

### Terraform / OpenTofu Infrastructure as Code

- [`terraform/`](terraform/) — Infrastructure as Code for Proxmox VE.
  - [`ubuntu-server/`](terraform/ubuntu-server/) — Ubuntu Server VM provisioning with cloud-init.
    - Uses `bpg/proxmox` provider (v0.88.0)
    - Features: Cloud image download, TPM 2.0, SSH key injection, QEMU Guest Agent
    - Supports PostgreSQL backend for remote state storage
  - [`lxc-grafana/`](terraform/lxc-grafana/) — Grafana LXC container for monitoring dashboards.
    - Unprivileged container with Ubuntu 24.04 LTS
    - Automated Grafana OSS installation via provisioner
    - Security hardening and SSH key authentication
  - [`lxc-vault/`](terraform/lxc-vault/) — HashiCorp Vault LXC container for secrets management.
    - Unprivileged container with Debian 13
    - Automated Vault installation and initialization
    - State file encryption with PBKDF2-AES-GCM
    - S3 remote state backend with locking support
    - Systemd service integration and optional Ansible user
  - [`lxc-netbox/`](terraform/lxc-netbox/) — NetBox LXC container for DCIM/IPAM platform.
    - Unprivileged container with Debian 13
    - Automated infrastructure provisioning with Vault integration
    - State file encryption with Vault Transit engine
    - S3 remote state backend with locking support
    - Ansible user auto-provisioning for automated deployment
    - Integrated with netbox-deploy Ansible playbook
  - [`fedora_core/`](terraform/fedora_core/) — Fedora CoreOS VM for container workloads.
    - Immutable OS designed for containerized applications (Podman/Docker)
    - **Single-stage Cloud-Init deployment** with native Ignition support
    - Uses `poseidon/ct` provider for Butane → Ignition transpilation
    - Dedicated coreos storage for images and snippets
    - One-time setup script: `scripts/bash/setup/proxmox_fcos_storage_setup.sh`
    - SSH key-only authentication (no passwords)
    - Static IP or DHCP network configuration
  - [`opensuseLeap/`](terraform/opensuseLeap/) — OpenSUSE Leap 15.6 cloud-image workstation with GPU passthrough.
    - High-performance workstation with full GPU support (AMD/Intel/NVIDIA)
    - USB device passthrough for peripherals and storage
    - UEFI boot with OVMF firmware and QEMU Guest Agent
    - io_uring disk I/O, writeback caching, dedicated IO threads
    - Hyper-V enlightenments for CPU performance optimization
    - State file encryption with PBKDF2-AES-GCM
    - AWS S3 backend support for remote state storage and locking
    - Ideal for gaming, AI/ML development, multimedia editing

### Automation Scripts

- [`scripts/`](scripts/) — Shell scripts and Ansible playbooks for host provisioning and automation.
  - [`ansible/`](scripts/ansible/) — Ansible configurations and playbooks.
    - [`playbooks/netbox-deploy/`](scripts/ansible/playbooks/netbox-deploy/) — NetBox DCIM/IPAM deployment
      - Deploys NetBox v4.4.9 with PostgreSQL 17 and Redis
      - Full automation with Vault secrets integration
      - Systemd services, Nginx reverse proxy, superuser creation
    - [`playbooks/maintenance/`](scripts/ansible/playbooks/maintenance/) — System maintenance
      - `update_packages.yml` — Multi-distro package updates (Debian, RHEL, SUSE)
    - [`playbooks/debug/`](scripts/ansible/playbooks/debug/) — Testing & debugging
      - `test_connection.yml` — SSH connectivity verification
  - [`bash/`](scripts/bash/) — Shell scripts for system setup.
    - [`setup/ansible_user_setup.sh`](scripts/bash/setup/ansible_user_setup.sh) — Ansible user provisioning
      - Creates automation user with SSH key authentication
      - Configures passwordless sudo for Ansible/Semaphore
      - Supports Debian/Ubuntu and RHEL/CentOS systems
    - [`setup/proxmox_fcos_storage_setup.sh`](scripts/bash/setup/proxmox_fcos_storage_setup.sh) — Fedora CoreOS storage setup
      - One-time setup for FCOS deployment on Proxmox
      - Creates /var/coreos storage with images and snippets
      - Downloads FCOS image via coreos-installer

## How to use

### Docker Compose

- Review the `template.yml` and `.env` files before running a Compose file.
- Store secrets (passwords, tokens) in a local `.env` or a secret manager — do not commit sensitive data to the repository.
- Run Compose files from the directory where they live: `docker compose up -d`.

### Terraform / OpenTofu

```bash
cd terraform/ubuntu-server

# Initialize with backend (requires PostgreSQL)
tofu init

# Review planned changes
tofu plan

# Apply infrastructure
tofu apply

# Get VM password (sensitive output)
tofu output -raw ubuntu_vm_password
```

**Fedora CoreOS deployment:**

```bash
# One-time setup on Proxmox host
# (Optional) Preview changes first
ssh root@proxmox-host 'bash -s -- --dry-run' < scripts/bash/setup/proxmox_fcos_storage_setup.sh

# Run actual setup
ssh root@proxmox-host < scripts/bash/setup/proxmox_fcos_storage_setup.sh

cd terraform/fedora_core

# Copy and configure variables
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Add your SSH key and Proxmox credentials

# Initialize providers (includes poseidon/ct for Butane)
tofu init

# Deploy VM (starts automatically with Ignition applied)
tofu apply

# Access VM
ssh core@<vm-ip>
```

**OpenSUSE Leap 15.6 cloud-image workstation with GPU passthrough:**

```bash
# Step 1: Identify your GPU and USB devices
lspci | grep -E "VGA|Audio"  # Find GPU device ID (e.g., 0b:00)
lsusb                        # Find USB device IDs (e.g., 046d:c328)

cd terraform/opensuseLeap

# Step 2: Create configuration with your hardware IDs
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Update:
                       # - GPU device ID: vm_hostpci0_id
                       # - USB device IDs: vm_usb_device_*_host
                       # - Proxmox credentials and endpoint

# Step 3: Initialize and deploy
tofu init
tofu plan
tofu apply

# Step 4: Access the VM
ssh user@<vm-ip>

# Step 5: Install GPU drivers in the VM
# For AMD: sudo zypper install amdgpu-pro
# For NVIDIA: Follow NVIDIA driver installation for OpenSUSE
```

> **Note:** Fedora CoreOS uses Ignition delivered via Proxmox Cloud-Init vendor data.
> This eliminates the need for complex kvm_arguments or Ansible post-provisioning.
>
> **GPU Passthrough**: Requires IOMMU enabled in BIOS and Proxmox.
> See [opensuseLeap/README.md](terraform/opensuseLeap/README.md) for detailed GPU setup.

**Prerequisites:**

- Proxmox VE API token with appropriate permissions
- PostgreSQL database for state storage (or modify backend.tf for local state)
- SSH key pair for VM access
- SSH access to Proxmox host (for Ignition upload)

### Scripts

```bash
cd scripts/bash/setup

# Copy and configure environment
cp .env.example .env
nano .env  # Add your SSH public key

# Run on target host
scp ansible_user_setup.sh .env user@target:/tmp/
ssh user@target 'sudo /tmp/ansible_user_setup.sh /tmp/.env'
```

### Ansible Playbooks

```bash
cd scripts/ansible

# Create inventory from example
cp inventory.yml.example inventory.yml
nano inventory.yml  # Add your hosts

# Test connectivity
ansible-playbook playbooks/debug/test_connection.yml

# Update all systems
ansible-playbook playbooks/maintenance/update_packages.yml

# Check mode (dry run)
ansible-playbook playbooks/maintenance/update_packages.yml --check

# Skip automatic reboot
ansible-playbook playbooks/maintenance/update_packages.yml --skip-tags reboot

# Update specific host
ansible-playbook playbooks/maintenance/update_packages.yml -l grafana
```

## Contributing

- If you add a new configuration, include a short `README.md` in the new folder with usage notes and any required host prerequisites (volumes, ports).

## License

- This repository contains configuration examples; verify licensing for any upstream images or components you use in production.

---

This README will be extended as new components are added.
