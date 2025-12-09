# Fedora CoreOS VM - OpenTofu Infrastructure

[![OpenTofu](https://img.shields.io/badge/OpenTofu-1.6+-purple?style=flat&logo=opentofu)](https://opentofu.org/)
[![Proxmox VE](https://img.shields.io/badge/Proxmox_VE-8.x+-orange?style=flat)](https://www.proxmox.com/)
[![Fedora CoreOS](https://img.shields.io/badge/Fedora_CoreOS-43-blue?style=flat&logo=fedora)](https://fedoraproject.org/coreos/)

OpenTofu/Terraform configuration for provisioning **Fedora CoreOS** virtual machines on **Proxmox VE** with **Ignition** configuration delivered via **Cloud-Init**.

## 🚀 Overview

Fedora CoreOS (FCOS) is an immutable, container-focused operating system designed for running containerized workloads securely and at scale. This module provisions FCOS VMs on Proxmox VE with:

- **Single-Stage Deployment**: OpenTofu creates VM with Ignition applied automatically
- **Cloud-Init Integration**: Native Proxmox support for Ignition delivery
- **SSH Key Authentication**: Passwordless, secure access
- **QEMU Guest Agent**: Full Proxmox integration
- **Container-Ready**: Optimized for Podman/Docker workloads

## 📋 Prerequisites

### Software Requirements

| Component | Version | Purpose |
|-----------|---------|---------|
| OpenTofu | >= 1.6.0 | Infrastructure as Code |
| Proxmox VE | >= 8.0 | Virtualization platform |
| FCOS Image | 43.x | QCOW2 image for VM |

### Proxmox Configuration

1. **API Token** (for OpenTofu):

   ```bash
   # Create user and token in Proxmox
   pveum user add terraform@pam --comment "Terraform automation"
   pveum aclmod / -user terraform@pam -role PVEVMAdmin
   pveum user token add terraform@pam terraform --privsep=0
   ```

2. **SSH Access** (for Ignition upload):

   ```bash
   # On Proxmox host - create ansible user for automation
   useradd -m -s /bin/bash ansible
   
   # Add SSH key for ansible user
   mkdir -p /home/ansible/.ssh
   echo "your-ssh-public-key" >> /home/ansible/.ssh/authorized_keys
   chown -R ansible:ansible /home/ansible/.ssh
   chmod 700 /home/ansible/.ssh
   chmod 600 /home/ansible/.ssh/authorized_keys
   ```

3. **Storage Setup** (one-time setup):

   ```bash
   # Run setup script on Proxmox host as root
   ssh root@proxmox-host < ../../scripts/bash/setup/proxmox_fcos_storage_setup.sh
   ```

   The setup script:
   - Creates `/var/coreos/{images,snippets}` directories
   - Registers `coreos` storage in Proxmox
   - Downloads FCOS image via `coreos-installer`

## 🎯 Quick Start

### 1. Initial Setup (One-Time)

Run the storage setup script on your Proxmox host:

```bash
# From repository root
ssh root@192.168.0.204 < scripts/bash/setup/proxmox_fcos_storage_setup.sh
```

### 2. Configure Variables

Create `terraform.tfvars`:

```hcl
# Proxmox Connection
proxmox_api_url  = "https://192.168.0.204:8006"
proxmox_api_token = "terraform@pam!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
proxmox_host     = "192.168.0.204"
proxmox_ssh_private_key = file("~/.ssh/ansible_proxmox")

# VM Configuration
vm_name        = "fcos-test"
vm_id          = 118
vm_ip_address  = "192.168.0.118/24"
vm_gateway     = "192.168.0.1"
vm_dns_servers = ["192.168.0.1", "8.8.8.8"]

# SSH Access
ssh_user       = "core"
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExamplePublicKey"

# FCOS Version
fcos_version   = "43.20251110.3.1"
```

### 3. Deploy VM

```bash
cd terraform/fedora_core

# Initialize providers
tofu init

# Deploy VM (starts automatically with Ignition applied)
tofu apply
```

### 4. Access VM

```bash
ssh core@192.168.0.118
```

## 📝 How It Works

Proxmox VE natively supports Ignition via Cloud-Init's vendor data mechanism.

**Workflow:**

1. **Generate Ignition**: Butane YAML → Ignition JSON
2. **Upload to Proxmox**: SCP Ignition to `/var/coreos/snippets/<vm_name>.ign`
3. **Configure Cloud-Init**: `--cicustom vendor=coreos:snippets/<vm_name>.ign`
4. **First Boot**: Ignition applies configuration

## 📚 References

- [Fedora CoreOS on Proxmox VE](https://docs.fedoraproject.org/en-US/fedora-coreos/provisioning-proxmoxve/)
- [Butane Configuration Specification](https://coreos.github.io/butane/config-fcos-v1_5/)

---

**Maintained by**: jegorik  
**Last Updated**: December 2025
