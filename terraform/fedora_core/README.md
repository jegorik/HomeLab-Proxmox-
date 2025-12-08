# Fedora CoreOS VM - OpenTofu Infrastructure

[![OpenTofu](https://img.shields.io/badge/OpenTofu-1.6+-purple?style=flat&logo=opentofu)](https://opentofu.org/)
[![Proxmox VE](https://img.shields.io/badge/Proxmox_VE-8.x+-orange?style=flat)](https://www.proxmox.com/)
[![Fedora CoreOS](https://img.shields.io/badge/Fedora_CoreOS-43-blue?style=flat&logo=fedora)](https://fedoraproject.org/coreos/)

OpenTofu/Terraform configuration for provisioning **Fedora CoreOS** virtual machines on **Proxmox VE** with **Ignition** configuration.

## 🚀 Overview

Fedora CoreOS (FCOS) is an immutable, container-focused operating system designed for running containerized workloads securely and at scale. This module provisions FCOS VMs on Proxmox VE with:

- **Two-Stage Deployment**: OpenTofu creates VM, Ansible applies Ignition
- **SSH Key Authentication**: Passwordless, secure access
- **QEMU Guest Agent**: Full Proxmox integration
- **Container-Ready**: Optimized for Podman/Docker workloads

## 📋 Prerequisites

### Software Requirements

| Component | Version | Purpose |
|-----------|---------|---------|
| OpenTofu | >= 1.6.0 | Infrastructure as Code (VM creation) |
| Ansible | >= 2.10 | Ignition injection and VM startup |
| Proxmox VE | >= 8.0 | Virtualization platform |
| FCOS Image | 43.x | QCOW2 image for VM |

### Proxmox Configuration

1. **API Token** (for OpenTofu VM creation):

   ```bash
   # Create user and token in Proxmox
   pveum user add terraform@pam --comment "Terraform automation"
   pveum aclmod / -user terraform@pam -role PVEVMAdmin
   pveum user token add terraform@pam terraform --privsep=0
   ```

2. **Ansible User with Sudo** (for Ignition injection):

   ```bash
   # On Proxmox host - create ansible user
   useradd -m -s /bin/bash ansible
   echo "ansible ALL=(ALL) NOPASSWD: /usr/sbin/qm" >> /etc/sudoers.d/ansible
   
   # Add SSH key for ansible user
   mkdir -p /home/ansible/.ssh
   echo "your-ssh-public-key" >> /home/ansible/.ssh/authorized_keys
   chown -R ansible:ansible /home/ansible/.ssh
   chmod 700 /home/ansible/.ssh
   chmod 600 /home/ansible/.ssh/authorized_keys
   ```

   > **Note**: The `kvm_arguments` parameter (used for Ignition via `-fw_cfg`) requires root privileges. We use Ansible with sudo instead of passing root password to OpenTofu.

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
├── outputs.tf                # Output values (incl. Ansible commands)
├── terraform.tfvars.example  # Example variable values
├── .gitignore                # Git ignore rules
├── README.md                 # This file
├── output/                   # Generated Ignition JSON files (gitignored)
└── butane/
    └── fcos-vm.yaml.tftpl    # Butane template (transpiled to Ignition)

# Related Ansible playbook
scripts/ansible_playbooks/
└── apply_fcos_ignition.yml   # Applies Ignition config to VM
```

## ⚙️ Configuration

### 1. Copy Example Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

### 2. Edit terraform.tfvars

```hcl
# Proxmox Connection
proxmox_api_url   = "https://192.168.0.204:8006"
proxmox_api_token = "terraform@pam!terraform=xxx-xxx-xxx"
proxmox_node      = "pve"

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

# Ignition output (for Ansible)
ignition_output_path = "./output"
```

### 3. For GitHub Actions / Semaphore UI

Set these as secrets/environment variables:

| Variable | Type | Description |
|----------|------|-------------|
| `TF_VAR_proxmox_api_url` | Secret | Proxmox API URL |
| `TF_VAR_proxmox_api_token` | Secret | API token |
| `TF_VAR_ssh_public_key` | Secret | SSH public key |

## 🚀 Two-Stage Deployment

This module uses a **two-stage deployment** approach:

1. **Stage 1 (OpenTofu)**: Creates VM (stopped) and generates Ignition JSON file
2. **Stage 2 (Ansible)**: Applies Ignition config via `qm set -args` and starts VM

### Stage 1: Create VM with OpenTofu

```bash
# Initialize providers
tofu init

# Preview changes
tofu plan

# Apply configuration (creates VM but doesn't start it)
tofu apply
```

After `tofu apply`, you'll see output with Ansible command to run.

### Stage 2: Apply Ignition with Ansible

```bash
# Option A: Run from this directory (recommended)
cd ../../scripts/ansible_playbooks
ansible-playbook apply_fcos_ignition.yml \
  -i "192.168.0.204," \
  -e "vm_id=$(cd ../../terraform/fedora_core && tofu output -raw vm_id)" \
  -e "proxmox_node=pve" \
  -e "ignition_file_path=$(cd ../../terraform/fedora_core && tofu output -raw ignition_file_path)" \
  -e "ansible_user=ansible" \
  -e "ansible_become=yes"

# Option B: Use the generated command from tofu output
tofu output ansible_playbook_command
```

### Semaphore UI Deployment

For Semaphore UI, create two task templates:

1. **Task 1 - Create VM (OpenTofu)**:
   - Environment: OpenTofu/Terraform
   - Directory: `terraform/fedora_core`
   - Command: `tofu apply -auto-approve`

2. **Task 2 - Apply Ignition (Ansible)**:
   - Environment: Ansible
   - Playbook: `scripts/ansible_playbooks/apply_fcos_ignition.yml`
   - Extra vars: `vm_id`, `proxmox_node`, `ignition_file_path`

## 📤 Outputs

After `tofu apply`, you'll have access to:

```bash
# Get VM ID for Ansible
tofu output vm_id

# Get path to generated Ignition file
tofu output ignition_file_path

# Get full Ansible command to run
tofu output ansible_playbook_command

# Get JSON vars for Ansible (programmatic use)
tofu output -json ansible_extra_vars

# After Ansible runs - get SSH command
tofu output ssh_connection_command
```

## 🔧 How It Works

### Two-Stage Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│                      STAGE 1: OpenTofu                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────────────┐ │
│  │ Butane YAML │───▶│ Ignition JSON│───▶│ ./output/ignition-  │ │
│  │ (Template)  │    │ (ct provider)│    │   <vm-name>.json    │ │
│  └─────────────┘    └──────────────┘    └─────────────────────┘ │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │            proxmox_virtual_environment_vm                    ││
│  │            (created but NOT started)                         ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      STAGE 2: Ansible                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────┐    ┌──────────────────────────────────┐│
│  │ Read ignition.json  │───▶│ sudo qm set <vmid> -args         ││
│  │ from Stage 1 output │    │   "-fw_cfg 'name=opt/com.coreos/ ││
│  └─────────────────────┘    │   config,string=<ignition>'"     ││
│                             └──────────────────────────────────┘│
│                                          │                       │
│                                          ▼                       │
│                             ┌──────────────────────────────────┐│
│                             │      sudo qm start <vmid>        ││
│                             │      (VM boots with Ignition)    ││
│                             └──────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### Why Two Stages?

The Proxmox API requires `root@pam` authentication with **password** to set `kvm_arguments`. Instead of storing root password in terraform.tfvars (security risk), we:

1. Use API token for VM creation (secure, limited privileges)
2. Use Ansible with sudo on Proxmox host for Ignition injection

### VM Boot Process

1. **First Boot**: VM reads Ignition config from QEMU firmware
2. **User Creation**: SSH user and keys configured
3. **rpm-ostree**: QEMU guest agent installed
4. **Reboot**: System reboots to apply layered packages
5. **Ready**: VM fully configured and accessible

## ⚠️ Known Limitations

### 1. Two-Stage Deployment Required

Due to Proxmox API restrictions, Ignition injection requires two stages:

```text
Stage 1: tofu apply     → Creates VM (stopped) + ignition.json
Stage 2: ansible-playbook → Applies Ignition via sudo, starts VM
```

This is more secure than storing root password in terraform.tfvars.

### 2. Comma Escaping in fw_cfg

Commas in Ignition JSON must be escaped as `,,` (handled automatically by Ansible playbook):

```yaml
# In apply_fcos_ignition.yml
ignition_escaped: "{{ ignition_content | replace(',', ',,') }}"
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
