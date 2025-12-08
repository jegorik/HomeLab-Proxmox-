# Terraform / OpenTofu Infrastructure as Code

[![OpenTofu](https://img.shields.io/badge/OpenTofu-1.6+-purple?style=flat&logo=opentofu)](https://opentofu.org/)
[![Proxmox VE](https://img.shields.io/badge/Proxmox_VE-8.x+-orange?style=flat)](https://www.proxmox.com/)

Infrastructure as Code templates for Proxmox VE virtual machines and containers.

## 📁 Structure

```text
terraform/
├── ubuntu-server/       # Ubuntu Server VM with cloud-init
├── lxc-grafana/         # Grafana LXC container
└── fedora_core/         # Fedora CoreOS VM with Ignition
```

## 📋 Available Templates

### ubuntu-server

**Purpose**: Provision Ubuntu Server VMs with cloud-init.

**Features**:

- Cloud image auto-download from Ubuntu CDN
- TPM 2.0 support for security features
- SSH key injection via cloud-init
- QEMU Guest Agent integration
- PostgreSQL backend for state storage

**Quick Start**:

```bash
cd ubuntu-server
tofu init
tofu plan
tofu apply
```

### lxc-grafana

**Purpose**: Deploy Grafana monitoring in an LXC container.

**Features**:

- Unprivileged container (security)
- Ubuntu 24.04 LTS base
- Automated Grafana OSS installation
- SSH key authentication
- Configurable resources

**Quick Start**:

```bash
cd lxc-grafana
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Configure settings
tofu init
tofu apply
```

### fedora_core

**Purpose**: Deploy Fedora CoreOS for container workloads.

**Features**:

- Immutable OS for containers (Podman/Docker)
- Ignition configuration (not cloud-init)
- Butane YAML templates
- Two-stage deployment (OpenTofu + Ansible)
- QEMU Guest Agent via rpm-ostree

**Quick Start**:

```bash
cd fedora_core
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Add SSH key, credentials
tofu init
tofu apply  # Creates VM (stopped)

# Apply Ignition via Ansible
ansible-playbook ../../scripts/ansible/playbooks/proxmox/apply_fcos_ignition.yml \
  -e @generated/<vm-name>-ansible-vars.yml
```

## 🔧 Common Configuration

### Provider Setup

All templates use the `bpg/proxmox` provider:

```hcl
provider "proxmox" {
  endpoint = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure = true  # For self-signed certs
}
```

### State Backend

Templates support PostgreSQL backend for state storage:

```bash
# Initialize with PostgreSQL backend
tofu init -backend-config=pg.backend.conf
```

Or use local state by modifying `backend.tf`.

### Required Variables

| Variable | Description |
|----------|-------------|
| `proxmox_api_url` | Proxmox API URL (https://host:8006) |
| `proxmox_api_token` | API token (user@realm!token=secret) |
| `proxmox_node` | Target Proxmox node name |
| `ssh_public_key` | SSH public key for VM access |

## 📝 Adding New Templates

1. Create new folder: `terraform/<template-name>/`
2. Include standard files:
   - `providers.tf` - Provider configuration
   - `variables.tf` - Input variables with validation
   - `main.tf` - Resource definitions
   - `outputs.tf` - Output values
   - `terraform.tfvars.example` - Example configuration
   - `README.md` - Documentation
   - `.gitignore` - Ignore sensitive files

3. Update this README
4. Update root project README

## 🔒 Security Notes

- Never commit `terraform.tfvars` with real credentials
- Use `.gitignore` to exclude sensitive files
- API tokens should have minimal required permissions
- Consider using Vault for secret management

---

See individual template READMEs for detailed documentation.
