# Terraform / OpenTofu Infrastructure as Code

[![OpenTofu](https://img.shields.io/badge/OpenTofu-1.6+-purple?style=flat&logo=opentofu)](https://opentofu.org/)
[![Proxmox VE](https://img.shields.io/badge/Proxmox_VE-8.x+-orange?style=flat)](https://www.proxmox.com/)

Infrastructure as Code templates for Proxmox VE virtual machines and containers.

## 📁 Structure

```text
terraform/
├── ubuntu-server/       # Ubuntu Server VM with cloud-init
├── lxc-grafana/         # Grafana LXC container
├── fedora_core/         # Fedora CoreOS VM with Ignition
└── opensuseLeap/        # OpenSUSE Leap 15.6 cloud-image workstation with GPU passthrough
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
- Ignition configuration delivered via Cloud-Init
- Butane YAML templates
- Single-stage deployment (OpenTofu only)
- One-time setup script for Proxmox storage
- Native Proxmox Cloud-Init support
- QEMU Guest Agent via rpm-ostree

**Quick Start**:

```bash
# One-time setup on Proxmox host
# Preview changes first (recommended)
ssh root@proxmox 'bash -s -- --dry-run' < ../scripts/bash/setup/proxmox_fcos_storage_setup.sh

# Run actual setup
ssh root@proxmox < ../scripts/bash/setup/proxmox_fcos_storage_setup.sh

cd fedora_core
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Add SSH key, credentials, Proxmox host
tofu init
tofu apply  # VM deploys with Ignition applied automatically

# Access VM
ssh core@<vm-ip>
```

### opensuseLeap

**Purpose**: Deploy OpenSUSE Leap 15.6 cloud-image workstations with GPU and USB passthrough.

**Features**:

- Full GPU passthrough support (AMD/Intel/NVIDIA)
- USB device passthrough (peripherals, storage)
- UEFI boot with OVMF firmware
- High-performance disk I/O (io_uring, writeback cache)
- QEMU Guest Agent integration
- Hyper-V enlightenments for efficiency
- State file encryption (PBKDF2-AES-GCM)
- AWS S3 backend support with state file locking
- Comprehensive GPU discovery helper scripts

**Use Cases**:

- 🎮 Gaming environments with modern GPUs
- 🤖 AI/ML development with CUDA/ROCm support
- 🎬 Multimedia editing and rendering workstations
- 💻 High-performance development environments

**Prerequisites**:

- Proxmox VE 8.x with IOMMU enabled in BIOS
- Compatible GPU with IOMMU support (AMD Polaris/RDNA, Intel Arc, NVIDIA)
- 24GB+ RAM recommended
- 150GB+ storage for VM disk

**Quick Start**:

```bash
# 1. Identify your GPU and USB devices
lspci | grep -E "VGA|Audio"  # For GPU
lsusb                        # For USB devices

# 2. Create configuration
cd opensuseLeap
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Update GPU/USB IDs, credentials

# 3. Deploy
tofu init
tofu plan
tofu apply

# 4. Access VM
ssh user@<vm-ip>

# 5. Install GPU drivers in VM
# For AMD: sudo zypper install amdgpu-pro
# For NVIDIA: Follow NVIDIA CUDA setup for OpenSUSE
```

**See [opensuseLeap/README.md](opensuseLeap/README.md) for detailed setup instructions.**

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
| ---------- | ------------- |
| `proxmox_api_url` | Proxmox API URL (<https://host:8006>) |
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

⚠️ **Critical Security Considerations**:

- **Never commit `terraform.tfvars`** with real credentials to version control
- Use `.gitignore` to exclude sensitive files: `terraform.tfvars`, `*.tfstate`, `pg.backend.conf`, `s3.backend.config`
- **API tokens** should have minimal required permissions only
- **Rotate credentials regularly**, especially if exposed accidentally
- Use environment variables for sensitive values:

```bash
export TF_VAR_proxmox_api_token="terraform@pve!token-id=secret"
export TF_VAR_proxmox_endpoint="https://proxmox-ip:8006"
```

- Consider using **HashiCorp Vault** or **AWS Secrets Manager** for production
- **GPU passthrough** exposes hardware directly; verify IOMMU isolation
- **USB passthrough** gives VM access to peripherals; audit which devices are exposed
- For **TLS/SSL**: Use proper certificates in production, not self-signed

```hcl
insecure = false  # Production
# tls_cert_path = "/etc/ssl/certs/proxmox-ca.pem"
```

---

**See individual template READMEs for detailed documentation and setup guides.**
