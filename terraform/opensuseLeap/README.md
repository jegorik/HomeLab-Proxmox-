# OpenSUSE Leap 16 Workstation VM - OpenTofu Infrastructure

[![OpenTofu](https://img.shields.io/badge/OpenTofu-1.6+-blue?style=flat&logo=opentofu)](https://opentofu.org/)
[![Proxmox](https://img.shields.io/badge/Proxmox-8.x-orange?style=flat&logo=proxmox)](https://www.proxmox.com/)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat)](LICENSE)

A comprehensive OpenTofu configuration for deploying high-performance OpenSUSE Leap 16 workstations with GPU and USB device passthrough on Proxmox VE infrastructure. Ideal for workstations requiring maximum performance for development, AI/ML workflows, gaming, or multimedia creation.

## Overview

This configuration manages a sophisticated OpenSUSE Leap 16 virtual machine with the following characteristics:

**Key Features:**

- ✅ **GPU Passthrough**: Full AMD/NVIDIA GPU support for high-performance graphics and compute workloads
- ✅ **USB Passthrough**: Direct passthrough of USB peripherals (keyboards, mice, storage devices)
- ✅ **UEFI Boot**: Modern OVMF firmware for secure and efficient booting
- ✅ **High Performance**: io_uring disk I/O, writeback caching, dedicated IO threads
- ✅ **QEMU Guest Agent**: Advanced VM management, IP detection, graceful shutdown
- ✅ **CPU Optimization**: Host passthrough with Hyper-V enlightenments for maximum performance
- ✅ **State Encryption**: Built-in PBKDF2-AES-GCM encryption for OpenTofu state files
- ✅ **Multi-Storage Support**: Flexible storage backend configuration (ZFS, Ceph, local storage)

**Recommended Use Cases:**

- 🎮 Gaming environments with modern GPU support
- 🤖 AI/ML development with CUDA/ROCm support
- 🎬 Multimedia editing and rendering workstations
- 💻 High-performance development environments
- 🔬 Scientific computing with GPU acceleration

## Prerequisites

### Proxmox VE Environment

1. **Proxmox VE 8.x or later** installed and configured
2. **IOMMU support enabled** in BIOS/UEFI and Proxmox kernel
3. **Compatible GPU** with IOMMU support:
   - AMD Polaris (RX 470, RX 480, RX 570, RX 580, etc.)
   - AMD RDNA (RX 5700, RX 6700, etc.)
   - Intel Arc GPUs (A380, A750, A770, etc.)
   - NVIDIA GPUs (requires careful IOMMU configuration)
4. **CPU with IOMMU support**:
   - AMD: Ryzen 1000 series and newer
   - Intel: Xeon E3/E5/Platinum, Core i7/i9 (6th gen and newer)
5. **Sufficient storage** (minimum 150GB for VM disk)
6. **24GB+ RAM** (minimum recommended with GPU)

### Proxmox Configuration

Before deployment, verify and configure Proxmox:

```bash
# Check IOMMU is enabled
dmesg | grep -i iommu

# Expected output includes:
# AMD-Vi: IOMMU disabled (code 0000)  <- If see this, enable in BIOS
# IOMMU Enabled

# Verify vfio-pci driver is available
lsmod | grep vfio_pci

# If not loaded, enable it:
echo 'vfio-pci' | sudo tee -a /etc/modules-load.d/vfio.conf
sudo update-initramfs -u -k all  # or sudo mkinitcpio -P for Arch
```

### API Access Requirements

1. **Proxmox API Token** with the following permissions:
   - `Datastore.AllocateSpace`
   - `Datastore.Audit`
   - `Nodes.Allocate`
   - `Nodes.PowerMgmt`
   - `VirtualMachines.Create`
   - `VirtualMachines.Modify`
   - `VirtualMachines.View`

2. **Create Token** in Proxmox GUI:
   - Login to Proxmox > Datacenter > API Tokens
   - Click "Add"
   - User: `terraform`
   - Token ID: `terraform-token`
   - Copy the full token string (format: `user@realm!token-id=secret`)

### Local Requirements

- **OpenTofu 1.6.0+** ([Install OpenTofu](https://opentofu.org/docs/intro/install/))
- **SSH key pair** for Proxmox host authentication
- **bash or zsh shell** for helper scripts
- **Standard Unix tools**: grep, sed, awk, lspci, lsusb

```bash
# Verify OpenTofu is installed
tofu --version

# Should output: OpenTofu v1.6.0 or later
```

### Hardware Discovery Tools

These commands help identify GPU and USB devices:

```bash
# List GPUs and audio devices
lspci | grep -E "VGA|Audio"

# Output example:
# 09:00.0 VGA compatible controller: AMD/ATI Radeon RX 5700
# 09:00.1 Audio device: AMD Navi HDMI Audio
# 09:00.2 PCI bridge

# List USB devices
lsusb

# Output example:
# Bus 004 Device 002: ID 18f8:0f99 Example Corp. USB Optical Mouse
# Bus 001 Device 003: ID 1a86:7523 Example Corp. Keyboard
```

## Directory Structure

```text
opensuseLeap/
├── README.md                          # This file
├── main.tf                            # Main VM resource configuration
├── variables.tf                       # Input variables and validation
├── outputs.tf                         # Output values after deployment
├── providers.tf                       # Provider configuration (Proxmox, AWS)
├── backend.tf                         # OpenTofu backend configuration
├── encryption.tf                      # State file encryption setup (optional)
├── terraform.tfvars.example          # Example configuration template
├── s3.backend.config                 # AWS S3 backend configuration file
├── terraform.tfstate                 # Current state file (LOCAL ONLY)
├── terraform.tfstate.backup          # Previous state backup
├── terraform.tfvars                  # Current configuration (SENSITIVE - DO NOT COMMIT)
├── .gitignore                        # Git ignore rules
├── .terraform/                       # OpenTofu working directory (auto-generated)
└── generated/                        # Generated files (auto-created)
```

## Quick Start

### 1. Identify Your Hardware

Run these commands on your Proxmox host to identify GPU and USB devices:

```bash
# Find GPU (usually high number like 09:00)
lspci | grep -E "VGA|Audio"

# Expected output for AMD GPU:
# 09:00.0 VGA compatible controller: AMD/ATI Radeon RX 5700
# 09:00.1 Audio device: AMD Navi HDMI Audio

# Convert to Proxmox format (add 0000: prefix and .0 suffix)
# 09:00.0 → 0000:09:00
# 09:00.1 → 0000:09:00.1

# Find USB devices
lsusb

# Output example:
# Bus 004 Device 002: ID 18f8:0f99 Example Corp. USB Optical Mouse
# Bus 001 Device 003: ID 1a86:7523 Example Corp. Keyboard
# Format for config: 18f8:0f99, 1a86:7523
```

### 2. Create Configuration File

```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your values (use your favorite editor)
nano terraform.tfvars

# Key values to update:
# - proxmox_endpoint: Your Proxmox IP (e.g., https://192.168.1.100:8006/)
# - proxmox_api_token: Token from step 1 (SECURITY: use env var instead)
# - vm_hostpci0_id: GPU device ID (e.g., 0000:09:00)
# - vm_hostpci4_id: GPU audio device ID if available (e.g., 0000:09:00.1)
# - vm_usb_device_*_host: Your USB device IDs (e.g., 18f8:0f99)
```

### 3. Initialize OpenTofu

```bash
# Download Proxmox provider
tofu init

# Output should show:
# Downloading Proxmox provider...
# Terraform has been successfully configured!
```

### 4. Review Planned Changes

```bash
# See what will be created
tofu plan

# Carefully review the output:
# - VM ID, name, and configuration
# - Resource count (should be 1 VM + networking)
# - No errors or warnings about missing variables
```

### 5. Deploy the VM

```bash
# Create the VM
tofu apply

# You'll be prompted:
# Do you want to perform these actions? [yes/no]
# Type: yes

# Wait for completion (usually 2-5 minutes)
# Final output will show:
# Apply complete! Resources: 1 added

# View outputs including connection info
tofu output

# Get SSH command:
tofu output -raw connection_info
```

### 6. Access Your VM

```bash
# Via Proxmox Console (recommended for first access)
https://your-proxmox-ip:8006/
> Click VM (ID 100 by default)
> Console tab
> noVNC or Spice viewer

# After network is configured, access via SSH:
ssh user@<vm-ip>

# Get VM IP from Proxmox GUI or:
tofu output vm_ipv4_addresses
```

## GPU Passthrough Configuration

### Discovering Your GPU

```bash
# List all PCI devices with graphics
lspci | grep -E "VGA|3D|Audio"

# Example output:
# 09:00.0 VGA compatible controller: AMD/ATI Polaris 10 Radeon RX 580
# 09:00.1 Audio device: ATI Technologies Inc. Navi HDMI Audio [AiO Chip]
# 09:00.2 Multimedia controller: ATI Technologies Inc. Navi DP Audio
# 09:00.3 PCI bridge: ATI Technologies Inc. Navi IOMMU Controller

# Get full details:
lspci -vv -s 09:00

# Output includes:
# Region 0: Memory at ... (64-bit, prefetchable)
# Region 2: Memory at ... (64-bit, prefetchable)
# Expansion ROM at ... [disabled]
```

### Configuring GPU IDs

Convert lspci format to Proxmox format:

| lspci Output | Proxmox Format | Note |
|-------------|-----------------|------|
| `09:00.0` | `0000:09:00` | Primary GPU VGA |
| `09:00.1` | `0000:09:00.1` | GPU Audio (optional) |
| `09:00.2` | `0000:09:00.2` | GPU Audio Controller (optional) |

Update `terraform.tfvars`:

```hcl
# Primary GPU (required)
vm_hostpci0_id = "0000:09:00"
vm_hostpci0_pcie = true      # Enable PCIe support
vm_hostpci0_xvga = true      # Set as primary VGA
vm_hostpci0_rombar = true    # Include GPU BIOS

# GPU Audio Device (optional but recommended for audio support)
vm_hostpci4_id = "0000:09:00.1"
vm_hostpci4_pcie = false
vm_hostpci4_xvga = false
vm_hostpci4_rombar = true
```

### Post-Deployment GPU Setup

After VM boots with GPU:

```bash
# SSH into the VM
ssh user@<vm-ip>

# Verify GPU is detected
lspci | grep -E "VGA|Audio"

# Install AMD GPU drivers (for OpenSUSE Leap)
sudo zypper addrepo https://download.opensuse.org/repositories/multimedia:/amdgpu/openSUSE_Leap_16/
sudo zypper refresh
sudo zypper install amdgpu-pro amdgpu-dkms

# Test GPU functionality
clinfo                    # Check OpenCL support
glxinfo | grep "OpenGL"   # Check graphics support
```

## USB Device Passthrough Configuration

### Discovering USB Devices

```bash
# List all USB devices with vendor and product IDs
lsusb

# Example output:
# Bus 004 Device 002: ID 18f8:0f99 Example Corp. USB Optical Mouse
# Bus 001 Device 003: ID 1a86:7523 Example Corp. Keyboard
# Bus 002 Device 005: ID 0951:1666 Example Storage Device

# Get detailed info:
lsusb -vv -d 18f8:0f99
```

### Proxmox USB ID Formats

USB devices can be passed through using two formats:

### Format 1: Vendor:Product ID (Recommended for stability)

```hcl
# Format: VENDOR_ID:PRODUCT_ID
vm_usb_device_1_host = "18f8:0f99"  # Example Mouse
vm_usb_device_2_host = "1a86:7523"  # Example Keyboard
```

### Format 2: Hub Port (for port-specific passthrough)

```hcl
# Format: BUS-PORT[.PORT]
vm_usb_device_1_host = "4-2"        # Bus 4, Port 2
vm_usb_device_2_host = "4-2.4"      # Bus 4, Port 2, SubPort 4
```

### USB Device Configuration

Update `terraform.tfvars`:

```hcl
# USB Device 1: Primary input device (keyboard)
vm_usb_device_1_host = "1a86:7523"  # Your keyboard ID
vm_usb_device_1_usb3 = false         # USB 2.0 for compatibility

# USB Device 2: Secondary input device (mouse)
vm_usb_device_2_host = "18f8:0f99"  # Your mouse ID
vm_usb_device_2_usb3 = true          # USB 3.0 if available

# USB Device 3: Storage device (optional)
vm_usb_device_3_host = "0951:1666"  # Example USB drive
vm_usb_device_3_usb3 = true

# USB Device 4: Additional peripheral (optional)
vm_usb_device_4_host = ""            # Leave empty if not used
vm_usb_device_4_usb3 = false
```

### Testing USB Passthrough

```bash
# After VM boots, verify USB devices are detected
lsusb

# Check for your devices:
# Bus 001 Device 002: ID 18f8:0f99 Example Corp. USB Optical Mouse
# Bus 001 Device 003: ID 1a86:7523 Example Corp. Keyboard
```

## Terraform Variables

### Essential Variables

| Variable | Type | Default | Required | Description |
|----------|------|---------|----------|-------------|
| `proxmox_endpoint` | string | - | Yes | Proxmox API URL (<https://ip:8006>) |
| `proxmox_api_token` | string | - | Yes | API token (user@realm!token=secret) |
| `proxmox_user` | string | - | Yes | SSH username for file uploads |
| `proxmox_node_name` | string | "pve" | No | Proxmox node hosting VM |
| `vm_id` | number | 100 | No | Unique VM ID in Proxmox |
| `vm_name` | string | "opensuseLeap16" | No | VM name in Proxmox |

### Hardware Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `vm_cpu_cores` | number | 6 | CPU cores (match your CPU count) |
| `vm_memory_dedicated` | number | 24576 | Dedicated RAM in MB (24GB) |
| `vm_disk_size` | number | 150 | Disk size in GB |
| `vm_disk_datastore_id` | string | "local-zfs" | Storage location |

### GPU Passthrough Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `vm_hostpci0_id` | string | "0000:09:00" | Primary GPU PCI ID |
| `vm_hostpci0_pcie` | bool | true | Enable PCIe passthrough |
| `vm_hostpci4_id` | string | "0000:09:00.1" | GPU audio PCI ID |
| `vm_hostpci4_pcie` | bool | false | GPU audio PCIe support |

### USB Passthrough Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `vm_usb_device_1_host` | string | "1a86:7523" | Device 1 ID (keyboard) |
| `vm_usb_device_1_usb3` | bool | false | Use USB 3.0 |
| `vm_usb_device_2_host` | string | "18f8:0f99" | Device 2 ID (mouse) |
| `vm_usb_device_2_usb3` | bool | false | Use USB 3.0 |

See `variables.tf` for complete list of all 100+ configurable variables.

## Outputs

After successful deployment, use these outputs to access your VM:

```bash
# Get all outputs
tofu output

# Specific outputs:
tofu output vm_id                    # VM ID
tofu output vm_ipv4_addresses        # Assigned IP addresses
tofu output connection_info          # Connection summary
```

Key outputs include:

- `vm_id`: VM identifier in Proxmox
- `vm_ipv4_addresses`: IPv4 addresses (for SSH)
- `vm_mac_addresses`: MAC addresses of network interfaces
- `vm_gpu_pci_id`: GPU ID passed through
- `vm_cpu_cores`: Allocated CPU cores
- `vm_memory_dedicated`: Allocated memory
- `connection_info`: Summary for easy reference

## Security Considerations

### 🔐 API Credentials

**Critical**: Never commit `terraform.tfvars` containing API tokens to version control.

**Safe approaches:**

1. **Environment Variables** (Recommended):

```bash
export TF_VAR_proxmox_api_token="terraform@pve!token-id=secret"
export TF_VAR_proxmox_endpoint="https://192.168.1.100:8006/"

tofu apply  # Variables are read from environment
```

2. **OpenTofu CLI** (For sensitive operations):

```bash
tofu apply \
  -var="proxmox_api_token=terraform@pve!token-id=secret" \
  -var="proxmox_endpoint=https://192.168.1.100:8006/"
```

3. **HashiCorp Vault** (Production):

```bash
vault login
vault write secret/homelab/proxmox \
  api_token="terraform@pve!token-id=secret" \
  endpoint="https://192.168.1.100:8006/"
```

4. **AWS Secrets Manager** (If using AWS backend):

```bash
aws secretsmanager create-secret \
  --name proxmox/terraform \
  --secret-string '{"api_token":"...","endpoint":"..."}'
```

### 🛡️ Sensitive Data in State Files

OpenTofu state files contain sensitive information:

```bash
# Encrypt state file with password
export TF_VAR_passphrase="your-16-plus-character-password"

# State encryption uses PBKDF2-AES-GCM (secure)
# 600,000 iterations, SHA-512
```

**Never store state files in public repositories!**

### 🔒 TLS/SSL Security

Default configuration accepts self-signed certificates:

```hcl
connection_option_insecure = true  # Development only!
```

For production, use proper certificates:

```hcl
connection_option_insecure = false
tls_cert_path = "/etc/ssl/certs/proxmox-ca.pem"
```

### 🔑 SSH Key Management

Ensure SSH keys for Proxmox access are properly secured:

```bash
# Generate SSH key (one-time)
ssh-keygen -t ed25519 -f ~/.ssh/proxmox -N ""

# Set strict permissions
chmod 600 ~/.ssh/proxmox
chmod 644 ~/.ssh/proxmox.pub

# Add to Proxmox authorized_keys
ssh-copy-id -i ~/.ssh/proxmox root@proxmox-host

# Configure local SSH config
cat >> ~/.ssh/config << EOF
Host proxmox
    HostName 192.168.1.100
    User terraform
    IdentityFile ~/.ssh/proxmox
    StrictHostKeyChecking no
EOF
```

### 🚨 IOMMU Security

GPU passthrough requires IOMMU groups:

```bash
# Verify IOMMU group isolation
for iommu_group in $(find /sys/kernel/iommu_groups/ -maxdepth 1 -mindepth 1 -type d); do
  echo "IOMMU group $(basename $iommu_group):"
  lspci -nns $(cat $iommu_group/devices/*/uevent | grep PCI_SLOT_NAME | cut -d= -f2) 2>/dev/null
  echo
done

# Ensure GPU is in isolated group (not shared with motherboard chipset)
# If shared, may need BIOS settings adjustment or different GPU slot
```

## Troubleshooting

### Problem: GPU Not Detected in VM

**Symptoms**: GPU shows in Proxmox config but not in VM (`lspci` shows nothing)

**Solution Steps**:

```bash
# 1. Verify IOMMU on Proxmox host
dmesg | grep -i iommu

# 2. Check GPU is actually passed through
lspci -k | grep -A 2 "AMD/ATI"

# Expected output:
# 09:00.0 VGA compatible controller: AMD/ATI Radeon RX 580
#     Kernel driver in use: vfio-pci
#     Kernel modules: amdgpu

# 3. Verify GPU is not in use by host
ps aux | grep -i amdgpu
ps aux | grep -i nouveau

# 4. If shows host driver, unbind GPU:
echo "0000:09:00" | sudo tee /sys/bus/pci/devices/0000:09:00/driver/unbind
echo "0000:09:00" | sudo tee /sys/bus/pci/drivers/vfio-pci/new_id

# 5. Verify vfio-pci is loaded
lsmod | grep vfio_pci

# 6. If missing, add to modules:
echo "vfio-pci" | sudo tee -a /etc/modules-load.d/vfio.conf
sudo update-initramfs -u -k all
```

### Problem: USB Device Not Found

**Symptoms**: USB passthrough configured but device not available in VM

**Solution Steps**:

```bash
# 1. Verify device ID is correct
lsusb | grep -i "your-device-name"

# 2. Check device isn't already in use
lsof /dev/bus/usb/*/device_number

# 3. Restart USB subsystem
sudo systemctl restart usbmuxd  # for macOS-bound devices
sudo usb-devices                 # for device info

# 4. Check hub port accessibility
lsusb -vv -d vendor:product

# 5. Try hub port format instead of vendor:product
# Change from: vm_usb_device_1_host = "18f8:0f99"
#         to: vm_usb_device_1_host = "4-2.1"
```

### Problem: High Latency or Stuttering

**Symptoms**: Graphics feel sluggish, mouse lags, frame drops

**Solution Steps**:

```hcl
# Increase IO performance in terraform.tfvars
vm_disk_aio      = "io_uring"      # Latest async I/O
vm_disk_cache    = "writeback"     # Write-back caching
vm_disk_iothread = true            # Dedicated IO thread
vm_cpu_type      = "host"          # Host CPU passthrough

# Disable unnecessary features
vm_tablet_device = false  # If not needed
vm_vga_memory    = 0      # GPU handles display
```

### Problem: VM Won't Boot After Passthrough

**Symptoms**: VM hangs after passthrough config, stuck in BIOS

**Solution Steps**:

```bash
# 1. Check device IOMMU group conflicts
echo "0000:09:00" | grep -f /sys/kernel/iommu_groups/*/devices/*/uevent

# 2. Ensure GPU doesn't share group with essential devices
cat /sys/kernel/iommu_groups/X/devices/*

# 3. Reset GPU:
echo "0000:09:00" | sudo tee /sys/bus/pci/devices/0000:09:00/reset

# 4. Try different BIOS settings:
# - PCIe ARI support: Enable
# - Above 4G Decoding: Enable
# - SR-IOV: Disable (if not needed)

# 5. Reboot Proxmox host (may be required after BIOS changes)
```

### Problem: State File Corruption

**Symptoms**: OpenTofu shows state file errors or incompatible version

**Recovery Steps**:

```bash
# 1. Backup current state
cp terraform.tfstate terraform.tfstate.corrupted

# 2. Restore from backup
cp terraform.tfstate.backup terraform.tfstate

# 3. Refresh state from actual resources
tofu refresh

# 4. If still issues, import existing VM
tofu import proxmox_virtual_environment_vm.opensuseLeap16 100
```

## Performance Tuning

### CPU Performance

```hcl
# Enable host CPU passthrough (best performance)
vm_cpu_type = "host"

# Hyper-V enlightenments for Windows-like efficiency
vm_kvm_arguments = "-cpu 'host,hv_ipi,hv_relaxed,hv_reset,...'"

# Disable CPU hotplug if not needed
vm_cpu_hotplugged = 0
```

### Memory Performance

```hcl
# Dedicated memory (not shared/ballooned)
vm_memory_dedicated = 24576

# Use floating memory for flexibility
vm_memory_floating = 16384  # Max memory for ballooning

# Disable shared memory unless needed
vm_memory_shared = 0
```

### Disk Performance

```hcl
# Use latest async I/O mechanism
vm_disk_aio = "io_uring"

# Write-back caching for speed (requires safe shutdown)
vm_disk_cache = "writeback"

# Direct block device discard for SSD
vm_disk_discard = "on"

# Dedicated IO thread
vm_disk_iothread = true

# Use raw format (not qcow2)
vm_disk_file_format = "raw"
```

### Network Performance

```hcl
# VirtIO for best performance
vm_network_model = "virtio"

# Match queues to CPU cores
vm_network_queues = 6  # Same as vm_cpu_cores

# Disable firewalling in VM network layer
vm_network_firewall = false
```

## Backup and Disaster Recovery

### Manual Snapshots

```bash
# Create snapshot before major changes
tofu plan -out=tfplan

# Take VM snapshot in Proxmox
qm snapshot 100 pre-gpu-passthrough

# If something goes wrong, restore:
qm snapshot 100 pre-gpu-passthrough -force

# Then re-import state
tofu refresh
```

### State File Backup

```bash
# Enable S3 backend for remote state backup
tofu init -backend-config=s3.backend.config

# Manual backup
cp terraform.tfstate s3://my-backups/opensuseLeap-$(date +%Y%m%d).tfstate

# AWS S3 versioning (automatic backups)
aws s3api put-bucket-versioning \
  --bucket my-terraform-state \
  --versioning-configuration Status=Enabled
```

### VM Backup (Proxmox Native)

```bash
# Create full VM backup
proxmox-backup-client backup vm --repository $REPO 100

# List backups
proxmox-backup-client list $REPO

# Restore if needed
proxmox-backup-client restore $BACKUP_ID /mnt/backup
```

## Post-Deployment Configuration

### OpenSUSE Leap System Setup

After VM boots:

```bash
# SSH into VM
ssh user@<vm-ip>

# Update system
sudo zypper update -y

# Install useful packages
sudo zypper install -y \
  git curl wget vim tmux htop \
  build-essential kernel-devel-default \
  gcc gfortran cmake

# For AI/ML workloads
sudo zypper install -y \
  python3 python3-devel python3-pip \
  cuda-toolkit  # if NVIDIA GPU

# For gaming/graphics
sudo zypper install -y \
  mesa-libGL \
  vulkan-tools \
  glxinfo

# Verify GPU is working
lspci | grep -E "VGA|Audio"
glxinfo | grep "OpenGL"
```

### Network Configuration

```bash
# Check network interface
ip addr

# Configure static IP (if DHCP not available)
sudo nmtui

# Or edit netplan
sudo vim /etc/netplan/01-netcfg.yaml
sudo netplan apply
```

### GPU Driver Installation

**For AMD GPU:**

```bash
# Add ROCm repository
wget -q -O - https://repo.radeon.com/rocm/rocm.gpg.key | sudo rpm --import -
sudo zypper addrepo --no-gpgcheck https://repo.radeon.com/rocm/zyp/main rocm-main

# Install drivers
sudo zypper install rocm-dkms rocm-libs

# Verify installation
rocm-smi
```

**For NVIDIA GPU:**

```bash
# Install NVIDIA drivers (if available)
sudo zypper install -y nvidia-driver-latest-dkms

# Verify
nvidia-smi
```

## Maintenance

### Regular Tasks

```bash
# Check for OpenTofu updates
tofu version

# Review plan regularly for drift
tofu plan

# Update providers
tofu init -upgrade

# Backup state files monthly
aws s3 sync . s3://my-backup/opensuseLeap-$(date +%Y-%m-%d)/
```

### Scaling Resources

```bash
# Increase CPU cores
vim terraform.tfvars  # Edit vm_cpu_cores
tofu plan
tofu apply

# Increase memory
# vim terraform.tfvars  # Edit vm_memory_dedicated
# tofu apply (may require VM restart)

# Expand disk (more complex, may need qemu-img)
```

## References and Documentation

- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
- [OpenTofu Documentation](https://opentofu.org/docs/)
- [Proxmox OpenTofu Provider](https://github.com/bpg/terraform-provider-proxmox)
- [AMD GPU Passthrough Guide](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)
- [GPU Passthrough Tutorial](https://www.redhat.com/en/blog/gpu-passthrough-setup)
- [OpenSUSE Leap Documentation](https://documentation.suse.com/)

## License

This configuration is provided under the MIT License. See LICENSE file for details.

## Support and Contributions

For issues, questions, or improvements:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review Proxmox logs: `tail -f /var/log/pve/tasks`
3. Check OpenTofu debugging: `TF_LOG=DEBUG tofu plan`
4. Report issues with full output and configuration details

---

**Last Updated**: December 2025  
**OpenTofu Version**: 1.6.0+  
**Proxmox Version**: 8.0+
