# Setup Scripts

Scripts for initial host configuration and preparation for Ansible management.

## 📋 Scripts

### ansible_user_setup.sh

Creates a dedicated Ansible automation user with:

- SSH public key authentication
- Passwordless sudo access
- Proper home directory and shell

See [parent README](../README.md) for detailed usage.

### proxmox_fcos_storage_setup.sh

One-time setup for Fedora CoreOS deployment on Proxmox VE:

- Creates `/var/coreos/{images,snippets}` directory structure
- Registers `coreos` storage in Proxmox with images and snippets support
- Downloads FCOS image using `coreos-installer` (or fallback to podman/docker)
- Validates storage configuration

**Usage:**

```bash
# Run directly on Proxmox host
ssh root@proxmox-host
bash /path/to/proxmox_fcos_storage_setup.sh

# Or remotely via SSH
ssh root@proxmox-host 'bash -s' < proxmox_fcos_storage_setup.sh

# Or from repository root
ssh root@proxmox-host < scripts/bash/setup/proxmox_fcos_storage_setup.sh
```

No environment variables needed - fully automated.

## 🚀 Quick Start

```bash
# 1. Prepare environment
cp .env.example .env
nano .env  # Add your SSH public key

# 2. Deploy to new host
TARGET="192.168.0.100"
scp ansible_user_setup.sh .env root@$TARGET:/tmp/
ssh root@$TARGET "bash /tmp/ansible_user_setup.sh /tmp/.env"

# 3. Verify
ssh ansible@$TARGET "whoami && sudo whoami"
# Should output: ansible \n root
```

## 📁 Files

| File | Purpose | Git Status |
|------|---------|------------|
| `ansible_user_setup.sh` | Create Ansible user | Tracked |
| `proxmox_fcos_storage_setup.sh` | Setup FCOS storage | Tracked |
| `.env.example` | Template for ansible_user_setup.sh | Tracked |
| `.env` | Your actual config | **Ignored** |

## ⚠️ Prerequisites

On target host:

- Root or sudo access for initial run
- SSH server running
- Internet access (for package installation if needed)
