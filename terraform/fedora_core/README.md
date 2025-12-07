# Fedora CoreOS VM - OpenTofu Infrastructure

[![OpenTofu](https://img.shields.io/badge/OpenTofu-1.6+-purple?style=flat&logo=opentofu)](https://opentofu.org/)
[![Proxmox VE](https://img.shields.io/badge/Proxmox_VE-8.x+-orange?style=flat)](https://www.proxmox.com/)
[![Fedora CoreOS](https://img.shields.io/badge/Fedora_CoreOS-43-blue?style=flat&logo=fedora)](https://fedoraproject.org/coreos/)

OpenTofu/Terraform configuration for provisioning **Fedora CoreOS** virtual machines on **Proxmox VE** with **Ignition** configuration.

## 🚀 Overview

Fedora CoreOS (FCOS) is an immutable, container-focused operating system designed for running containerized workloads securely and at scale. This module provisions FCOS VMs on Proxmox VE with:

- **Ignition Configuration**: First-boot provisioning via QEMU fw_cfg
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

1. **API Token** (for standard operations):

   ```bash
   # Create user and token in Proxmox
   pveum user add terraform@pam --comment "Terraform automation"
   pveum aclmod / -user terraform@pam -role PVEVMAdmin
   pveum user token add terraform@pam terraform --privsep=0
   ```

2. **Root Password** (required for Ignition injection):
   > ⚠️ **CRITICAL**: The `kvm_arguments` parameter (used for Ignition via `-fw_cfg`) requires `root@pam` authentication with **password**. API tokens do **NOT** work for this operation.

### FCOS Image

Download the Proxmox-optimized QCOW2 image:

```bash
# On Proxmox host
cd /var/lib/vz/import

# Download latest stable FCOS image
STREAM=stable
VERSION=$(curl -s "https://builds.coreos.fedoraproject.org/streams/${STREAM}.json" | jq -r '.architectures.x86_64.artifacts.metal.release')
wget "https://builds.coreos.fedoraproject.org/prod/streams/${STREAM}/builds/${VERSION}/x86_64/fedora-coreos-${VERSION}-proxmoxve.x86_64.qcow2"
```

## 🏗️ Project Structure

```text
fedora_core/
├── providers.tf              # Provider configuration
├── variables.tf              # Input variables with documentation
├── main.tf                   # VM and resource definitions
├── outputs.tf                # Output values
├── backend.tf                # State backend configuration
├── terraform.tfvars.example  # Example variable values
├── .gitignore                # Git ignore rules
├── README.md                 # This file
└── butane/
    └── fcos-vm.yaml.tftpl    # Butane template (transpiled to Ignition)
```

## ⚙️ Configuration

### 1. Copy Example Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

### 2. Edit terraform.tfvars

```hcl
# Proxmox Connection
proxmox_api_url       = "https://192.168.0.204:8006"
proxmox_api_token     = "terraform@pam!terraform=xxx-xxx-xxx"
proxmox_root_password = "your-root-password"  # Required for Ignition
proxmox_node          = "pve"

# VM Configuration
vm_name       = "fcos-container-host"
vm_cpu_cores  = 4
vm_memory     = 8192  # 8 GB
vm_disk_size  = "64G"

# SSH Access (REQUIRED)
ssh_user       = "core"
ssh_public_key = "ssh-ed25519 AAAAC3... your-key"

# Features
enable_qemu_guest_agent = true
timezone                = "Europe/Kiev"
```

### 3. For GitHub Actions / Semaphore UI

Set these as secrets/environment variables:

| Variable | Type | Description |
|----------|------|-------------|
| `TF_VAR_proxmox_api_url` | Secret | Proxmox API URL |
| `TF_VAR_proxmox_api_token` | Secret | API token |
| `TF_VAR_proxmox_root_password` | Secret | Root password for Ignition |
| `TF_VAR_ssh_public_key` | Secret | SSH public key |

## 🚀 Deployment

### Local Deployment

```bash
# Initialize providers
tofu init

# Preview changes
tofu plan

# Apply configuration
tofu apply

# View outputs
tofu output
```

### Semaphore UI Deployment

1. Create a new Task Template
2. Set Environment: `OpenTofu/Terraform`
3. Add environment variables (see above)
4. Repository: Your GitHub repo URL
5. Playbook Directory: `terraform/fedora_core`

## 📤 Outputs

After deployment, you'll have access to:

```bash
# Get SSH command
tofu output ssh_connection_command
# Output: ssh core@192.168.0.50

# Get VM IP
tofu output vm_primary_ip

# Get VM ID
tofu output vm_id
```

## 🔧 How It Works

### Ignition Injection Flow

```text
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Butane YAML    │────▶│  Ignition JSON  │────▶│  QEMU fw_cfg    │
│  (Human-read)   │     │  (Machine-read) │     │  (VM firmware)  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                      │                       │
         │                      │                       │
         ▼                      ▼                       ▼
   butane/*.tftpl        ct_config data           kvm_arguments
   Template vars         source transpiles        -fw_cfg 'name=...'
```

### VM Boot Process

1. **First Boot**: VM reads Ignition config from firmware
2. **User Creation**: SSH user and keys configured
3. **rpm-ostree**: QEMU guest agent installed
4. **Reboot**: System reboots to apply layered packages
5. **Ready**: VM fully configured and accessible

## ⚠️ Known Limitations

### 1. Root Password Requirement

The `kvm_arguments` parameter requires `root@pam` authentication:

```hcl
# This WORKS (with root password)
proxmox_root_password = "actual-password"

# This DOES NOT WORK (API token only)
proxmox_api_token = "token-only"  # Ignition won't be injected
```

**Workaround**: Use Proxmox root password for initial provisioning, then manage VMs via API token.

### 2. Comma Escaping in fw_cfg

Commas in Ignition JSON must be escaped as `,,`:

```hcl
# Handled automatically in main.tf
kvm_arguments = "-fw_cfg 'name=opt/com.coreos/config,string=${replace(ignition_json, ",", ",,")}}'"
```

### 3. Guest Agent Reboot

QEMU guest agent installation requires a reboot (rpm-ostree layering):

- First boot: Installs packages, triggers reboot
- Second boot: Guest agent active
- Total time: ~3-5 minutes

## 🔄 Updates

### Updating FCOS Version

```hcl
# In terraform.tfvars
fcos_version = "43.20251215.1.0"  # New version
```

Then apply changes (creates new VM or requires recreation).

### Rebasing FCOS Stream

On the running VM:

```bash
sudo rpm-ostree rebase fedora/stable/x86_64/coreos
sudo systemctl reboot
```

## 🔐 Security Considerations

1. **Never commit `terraform.tfvars`** with real credentials
2. **Use SSH keys only** - FCOS doesn't support password auth
3. **Rotate API tokens** regularly
4. **Consider** using Vault for secret management
5. **Enable Proxmox firewall** if needed

## 📚 Resources

- [Fedora CoreOS Documentation](https://docs.fedoraproject.org/en-US/fedora-coreos/)
- [Butane Configuration Spec](https://coreos.github.io/butane/)
- [Ignition Configuration Spec](https://coreos.github.io/ignition/)
- [bpg/proxmox Provider](https://registry.terraform.io/providers/bpg/proxmox/latest)
- [poseidon/ct Provider](https://registry.terraform.io/providers/poseidon/ct/latest)

## 📝 License

MIT License - See [LICENSE](../LICENSE) for details.

---

**Author**: jegorik  
**Last Updated**: December 2025
