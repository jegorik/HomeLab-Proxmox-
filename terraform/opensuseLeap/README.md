# OpenSUSE Leap 15.6 Workstation VM - OpenTofu Infrastructure

[![OpenTofu](https://img.shields.io/badge/OpenTofu-1.6+-blue?style=flat&logo=opentofu)](https://opentofu.org/)
[![Proxmox](https://img.shields.io/badge/Proxmox-8.x-orange?style=flat&logo=proxmox)](https://www.proxmox.com/)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat)](LICENSE)

A comprehensive OpenTofu configuration for deploying high-performance OpenSUSE Leap 15.6 workstations with GPU and USB device passthrough on Proxmox VE infrastructure. Includes cloud-init automated provisioning, SSH key management, and multi-user account creation.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Cloud-Init Setup](#cloud-init-setup)
- [GPU Passthrough Configuration](#gpu-passthrough-configuration)
- [USB Device Passthrough](#usb-device-passthrough)
- [Configuration Variables](#configuration-variables)
- [Outputs](#outputs)
- [Known Issues](#known-issues)
- [Troubleshooting](#troubleshooting)
- [Performance Tuning](#performance-tuning)
- [Security Considerations](#security-considerations)
- [Maintenance](#maintenance)
- [References](#references)

## Overview

This OpenTofu/Terraform configuration creates enterprise-grade OpenSUSE Leap 15.6 virtual machines on Proxmox VE with advanced features for development, gaming, and AI/ML workloads.

### Architecture

```
┌──────────────────────────────────────────────────────────────┐
│ Proxmox VE Host                                              │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ OpenSUSE Leap 15.6 VM                                  │  │
│  │                                                        │  │
│  │  CPU: Host passthrough (Hyper-V enlightenments)        │  │
│  │  Memory: Dedicated with ballooning                     │  │
│  │  Disk: SCSI with io_uring (high performance)           │  │
│  │  Network: VirtIO multi-queue                           │  │
│  │  GPU: PCIe passthrough (AMD/NVIDIA/Intel)              │  │
│  │  USB: Direct device passthrough                        │  │
│  │  Agent: QEMU Guest Agent                               │  │
│  │                                                        │  │
│  │  Users:                                                │  │
│  │  ├─ ansible (automation, passwordless sudo)            │  │
│  │  ├─ admin (manual admin, password-protected sudo)      │  │
│  │  └─ opensuse (default cloud-init user)                 │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

## Features

### Core Capabilities

✅ **Cloud-Init Provisioning**: Automated user and system configuration at VM creation  
✅ **Multi-User Management**: Ansible service account + admin user with SSH key authentication  
✅ **Automated Cloud Image Download**: Fetches and caches openSUSE cloud image in Proxmox storage  
✅ **SSH Key-Based Authentication**: Secure access without password authentication  
✅ **GPU Passthrough**: Full AMD/NVIDIA/Intel GPU support for high-performance workloads  
✅ **USB Passthrough**: Direct passthrough of USB peripherals (keyboards, mice, storage)  
✅ **UEFI Boot**: Modern OVMF firmware for secure booting  
✅ **High Performance**: io_uring disk I/O, writeback caching, dedicated IO threads  
✅ **QEMU Guest Agent**: Advanced VM management and IP detection  
✅ **State Encryption**: PBKDF2-AES-GCM encryption for OpenTofu state files  
✅ **Lifecycle Management**: Prevent accidental deletion, ignore state drift

### Recommended Use Cases

🎮 **Gaming environments** with modern GPU support  
🤖 **AI/ML development** with CUDA/ROCm support  
🎬 **Multimedia editing** and rendering workstations  
💻 **High-performance development** environments  
🔬 **Scientific computing** with GPU acceleration  
📊 **Data science workloads** with Python/R environments

## Prerequisites

### Hardware Requirements

**Minimum:**
- Proxmox VE 8.x or later
- CPU with IOMMU support (AMD-Vi or Intel VT-d)
- 24GB+ RAM for GPU workstation VMs
- 150GB+ storage for VM disk
- Compatible GPU (AMD, NVIDIA, or Intel Arc)

**Supported CPUs:**
- AMD: Ryzen 1000 series and newer, EPYC
- Intel: Core i5/i7/i9 (6th gen+), Xeon E3/E5/Platinum

**Supported GPUs:**
- AMD: Polaris (RX 470/480/570/580), RDNA (RX 5000/6000/7000)
- NVIDIA: GeForce GTX/RTX series, Quadro, Tesla
- Intel: Arc A380/A750/A770

### Proxmox VE Configuration

#### 1. Enable IOMMU in BIOS/UEFI

Access your system BIOS/UEFI and enable:
- AMD: **AMD-Vi** or **IOMMU**
- Intel: **VT-d** (Virtualization Technology for Directed I/O)

#### 2. Enable IOMMU in Proxmox Kernel

Edit GRUB configuration:

```bash
# For AMD processors
nano /etc/default/grub
# Add to GRUB_CMDLINE_LINUX_DEFAULT:
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"

# For Intel processors
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"

# Update GRUB
update-grub
reboot
```

#### 3. Verify IOMMU is Enabled

```bash
# Check IOMMU status
dmesg | grep -i iommu

# Expected output includes:
# AMD-Vi: AMD IOMMUv2 loaded and initialized
# or
# DMAR: Intel(R) Virtualization Technology for Directed I/O
```

#### 4. Load VFIO Modules

```bash
# Add VFIO modules to load at boot
cat >> /etc/modules <<EOF
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
EOF

# Update initramfs
update-initramfs -u -k all
reboot
```

#### 5. Enable Snippets Content Type

**⚠️ CRITICAL**: Cloud-init requires snippets enabled on storage:

```bash
# Enable snippets on local storage
pvesm set local --content iso,vztmpl,snippets

# Verify it's enabled
pvesm status | grep snippets
# Should show: local ... iso,vztmpl,snippets
```

**GUI Alternative:**
- Proxmox UI → Datacenter → Storage → local → Edit
- Content section: Check "Snippets" checkbox
- Click OK

#### 6. Create API Token

In Proxmox web interface:

1. Navigate to: **Datacenter** → **Permissions** → **API Tokens**
2. Click **Add**
3. User: `terraform@pve` (create user if needed)
4. Token ID: `terraform-token`
5. Uncheck **Privilege Separation**
6. Click **Add**
7. **Copy the full token** (format: `terraform@pve!terraform-token=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)

**Required Permissions** for terraform user:
- Datastore.AllocateSpace
- Datastore.Audit
- Pool.Allocate
- Sys.Audit
- Sys.Console
- Sys.Modify
- VM.Allocate
- VM.Audit
- VM.Clone
- VM.Config.CDROM
- VM.Config.CPU
- VM.Config.Cloudinit
- VM.Config.Disk
- VM.Config.HWType
- VM.Config.Memory
- VM.Config.Network
- VM.Config.Options
- VM.Console
- VM.Monitor
- VM.PowerMgmt

### Local Requirements

#### Install OpenTofu

```bash
# Download OpenTofu (Linux)
wget -O- https://get.opentofu.org/install-opentofu.sh | sh

# Verify installation
tofu --version
# Should output: OpenTofu v1.6.0 or later
```

Alternative installation methods: https://opentofu.org/docs/intro/install/

#### Generate SSH Keys for Cloud-Init Users

```bash
# Generate Ansible service account SSH key
ssh-keygen -t ed25519 -f ~/.ssh/ansible_key -N "" -C "ansible@homelab"

# Generate Admin user SSH key
ssh-keygen -t ed25519 -f ~/.ssh/admin_key -N "" -C "admin@homelab"

# Set proper permissions
chmod 600 ~/.ssh/ansible_key ~/.ssh/admin_key
chmod 644 ~/.ssh/ansible_key.pub ~/.ssh/admin_key.pub

# Display public keys (needed for terraform.tfvars)
echo "Ansible key:"
cat ~/.ssh/ansible_key.pub
echo ""
echo "Admin key:"
cat ~/.ssh/admin_key.pub
```

**Key Types:**
- `ed25519`: Modern, secure, recommended (default)
- `rsa -b 4096`: Compatible with older systems
- `ecdsa -b 521`: Alternative modern option

#### Generate SSH Key for Proxmox Host Access

```bash
# Generate key for Proxmox host connection
ssh-keygen -t ed25519 -f ~/.ssh/proxmox_terraform -N ""

# Copy to Proxmox host
ssh-copy-id -i ~/.ssh/proxmox_terraform root@<proxmox-ip>

# Test connection
ssh -i ~/.ssh/proxmox_terraform root@<proxmox-ip>
```

### Hardware Discovery

#### Find Your GPU Device ID

```bash
# On Proxmox host, list all GPUs
lspci | grep -E "VGA|Audio|3D"

# Example output:
# 09:00.0 VGA compatible controller: AMD/ATI Radeon RX 580
# 09:00.1 Audio device: AMD/ATI Radeon RX 580 HDMI Audio

# Convert to Proxmox format (add 0000: prefix, remove .0 suffix)
# 09:00.0 → 0000:09:00
# 09:00.1 → 0000:09:00.1

# Get detailed device info
lspci -vv -s 09:00.0
```

#### Find Your USB Devices

```bash
# List all USB devices
lsusb

# Example output:
# Bus 001 Device 003: ID 046d:c328 Logitech, Inc. Corded Mouse
# Bus 004 Device 002: ID 413c:2113 Dell Computer Corp. KB216 Keyboard

# USB ID format: vendorID:productID
# Mouse: 046d:c328
# Keyboard: 413c:2113
```

## Quick Start

### 1. Clone Repository

```bash
git clone <repository-url>
cd opensuseLeap15.6
```

### 2. Create Configuration File

```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

**Minimum required changes in `terraform.tfvars`:**

```hcl
# Proxmox connection
proxmox_endpoint  = "https://192.168.1.100:8006/"  # Your Proxmox IP
proxmox_api_token = "terraform@pve!terraform-token=YOUR_ACTUAL_TOKEN"
proxmox_user      = "root"  # Or your Proxmox SSH user

# VM identity
vm_id   = 300  # Unique VM ID
vm_name = "opensuse-workstation"

# Hardware (adjust for your system)
vm_cpu_cores        = 8
vm_memory_dedicated = 24576  # 24GB

# Storage
vm_disk_datastore_id     = "local-lvm"  # Your storage
vm_efi_disk_datastore_id = "local-lvm"

# Cloud-init (if enabled)
cloudinit_enabled    = true
ansible_ssh_key_path = "~/.ssh/ansible_key.pub"
admin_ssh_key_path   = "~/.ssh/admin_key.pub"

# GPU passthrough (update with your device IDs)
vm_hostpci0_id = "0000:09:00"    # Your GPU
vm_hostpci4_id = "0000:09:00.1"  # Your GPU audio

# USB passthrough (update with your device IDs)
vm_usb_device_1_host = "046d:c328"  # Your mouse
vm_usb_device_2_host = "413c:2113"  # Your keyboard
```

### 3. Initialize OpenTofu

```bash
# Initialize providers and modules
tofu init

# Expected output:
# Initializing the backend...
# Initializing provider plugins...
# - Finding bpg/proxmox versions matching "0.89.1"...
# - Installing bpg/proxmox v0.89.1...
# OpenTofu has been successfully initialized!
```

### 4. Review Configuration

```bash
# Generate execution plan
tofu plan

# Review the output carefully:
# - Verify VM configuration
# - Check resource counts
# - Look for any errors or warnings
```

### 5. Deploy VM

```bash
# Apply configuration
tofu apply

# Review the plan and type: yes

# Wait for completion (typically 3-10 minutes)
# Progress indicators show resource creation status
```

### 6. Access Your VM

#### Via Proxmox Console

1. Open Proxmox web interface: `https://<proxmox-ip>:8006/`
2. Navigate to your VM (ID from `vm_id` variable)
3. Click **Console** tab
4. Select **noVNC** or **SPICE** viewer

#### Via SSH (after cloud-init completes)

```bash
# Get VM IP address
tofu output connection_info

# SSH as ansible user
ssh -i ~/.ssh/ansible_key ansible@<vm-ip>

# SSH as admin user
ssh -i ~/.ssh/admin_key admin@<vm-ip>
```

## Cloud-Init Setup

### Overview

Cloud-init automatically provisions the VM with:
- User accounts (ansible + admin)
- SSH key authentication
- Essential packages
- System hardening (SSH config, firewall)
- QEMU guest agent

### Configuration

Enable cloud-init in `terraform.tfvars`:

```hcl
# Enable new VM creation with cloud-init
vm_create_new        = true
cloudinit_enabled    = true
cloud_image_download = true

# SSH keys
ansible_ssh_key_path = "~/.ssh/ansible_key.pub"
admin_ssh_key_path   = "~/.ssh/admin_key.pub"

# Admin username
cloudinit_admin_username = "admin"

# Network configuration
cloudinit_use_dhcp   = true  # or false for static IP
cloudinit_dns_domain = "local"

# For static IP (when cloudinit_use_dhcp = false):
cloudinit_ipv4_address = "192.168.1.100/24"
cloudinit_ipv4_gateway = "192.168.1.1"
```

### User Accounts Created

| User | Purpose | Sudo | Password | SSH Key |
|------|---------|------|----------|---------|
| **ansible** | Automation | Passwordless | Locked | ansible_key |
| **admin** | Manual admin | Password required | Disabled | admin_key |
| **opensuse** | Default | Standard | Disabled | Optional |

### Package Installation

Cloud-init installs these packages (openSUSE-specific):

**System:**
- `qemu-guest-agent` - VM management and IP detection
- `net-tools-deprecated` - Network utilities (ifconfig, netstat)
- `dbus-1` - D-Bus message bus

**Development:**
- `patterns-devel-base-devel_basis` - Build tools (gcc, make, etc.)
- `python3`, `python3-pip`, `python3-devel` - Python environment

**Utilities:**
- `curl`, `wget`, `git` - Download and version control
- `vim`, `nano`, `tmux` - Text editors and terminal multiplexer
- `htop` - Process viewer

### Testing Cloud-Init

After VM creation:

```bash
# SSH to VM
ssh -i ~/.ssh/admin_key admin@<vm-ip>

# Check cloud-init status
sudo cloud-init status --long
# Should show: status: done

# View cloud-init logs
sudo cat /var/log/cloud-init.log
sudo cat /var/log/cloud-init-output.log

# Test passwordless sudo (ansible user)
ssh -i ~/.ssh/ansible_key ansible@<vm-ip> "sudo whoami"
# Should output: root (without password prompt)

# Test password-required sudo (admin user)
ssh -i ~/.ssh/admin_key admin@<vm-ip> "sudo whoami"
# Should prompt for password
```

### Troubleshooting Cloud-Init

#### Cloud-Init Not Running

```bash
# Check status
sudo cloud-init status

# View detailed logs
sudo journalctl -u cloud-init

# Manually trigger cloud-init (for testing)
sudo cloud-init clean
sudo cloud-init init
```

#### SSH Key Not Working

```bash
# Verify key permissions on local machine
ls -la ~/.ssh/ansible_key*
# Should show: -rw------- (600) for private key
#              -rw-r--r-- (644) for public key

# Check authorized_keys in VM
ssh -i ~/.ssh/admin_key admin@<vm-ip>
cat ~/.ssh/authorized_keys

# Verify key fingerprint matches
ssh-keygen -l -f ~/.ssh/admin_key.pub
```

#### Packages Failed to Install

Check for openSUSE-specific package name issues:

```bash
# View package installation errors
sudo cat /var/log/cloud-init-output.log | grep -i error

# Common issues:
# - "build-essential" → use "patterns-devel-base-devel_basis"
# - "dbus-daemon" → use "dbus-1"
# - "net-tools" → use "net-tools-deprecated"
```

## GPU Passthrough Configuration

### Prerequisites

Verify IOMMU is configured (see [Proxmox VE Configuration](#proxmox-ve-configuration)):

```bash
# Check IOMMU groups
for iommu_group in $(find /sys/kernel/iommu_groups/ -maxdepth 1 -mindepth 1 -type d); do
    echo "IOMMU group $(basename $iommu_group):"
    lspci -nns $(cat $iommu_group/devices/*/uevent | grep PCI_SLOT_NAME | cut -d= -f2)
    echo
done
```

**Important**: GPU should be in isolated IOMMU group (not sharing with critical devices).

### Configure GPU Passthrough

#### 1. Identify GPU Device IDs

```bash
# Find your GPU
lspci | grep -E "VGA|Audio"

# Example output:
# 09:00.0 VGA compatible controller: AMD/ATI Radeon RX 580 2048SP
# 09:00.1 Audio device: AMD/ATI Radeon RX 580 HDMI Audio

# Convert to Proxmox format:
# 09:00.0 → "0000:09:00"
# 09:00.1 → "0000:09:00.1"
```

#### 2. Update terraform.tfvars

```hcl
# Primary GPU (VGA controller)
vm_hostpci0_id     = "0000:09:00"    # Your GPU device ID
vm_hostpci0_pcie   = true            # Enable PCIe
vm_hostpci0_rombar = true            # Include GPU BIOS
vm_hostpci0_xvga   = true            # Primary VGA

# GPU Audio (HDMI/DP audio)
vm_hostpci4_id     = "0000:09:00.1"  # Your audio device ID
vm_hostpci4_pcie   = false           # Audio doesn't need PCIe
vm_hostpci4_rombar = true
vm_hostpci4_xvga   = false           # Not VGA

# Disable default VGA (required for GPU passthrough)
vm_vga_type = "none"
```

#### 3. Uncomment GPU Blocks in main.tf

Edit `main.tf` and uncomment the hostpci blocks (around line 360):

```terraform
# Uncomment these blocks:
hostpci {
  device = "hostpci0"
  id     = var.vm_hostpci0_id
  pcie   = var.vm_hostpci0_pcie
  rombar = var.vm_hostpci0_rombar
  xvga   = var.vm_hostpci0_xvga
}

hostpci {
  device = "hostpci4"
  id     = var.vm_hostpci4_id
  pcie   = var.vm_hostpci4_pcie
  rombar = var.vm_hostpci4_rombar
  xvga   = var.vm_hostpci4_xvga
}
```

#### 4. Apply Changes

```bash
tofu apply
```

### Post-Deployment GPU Setup

After VM boots with GPU:

```bash
# SSH into VM
ssh -i ~/.ssh/admin_key admin@<vm-ip>

# Verify GPU is detected
lspci | grep -E "VGA|Audio"
# Should show your GPU

# Install AMD GPU drivers (for OpenSUSE)
sudo zypper addrepo --refresh \
  https://download.opensuse.org/repositories/X11:/XOrg/openSUSE_Leap_15.6/ x11-xorg

# Install mesa drivers
sudo zypper install -y \
  Mesa-dri \
  Mesa-libGL1 \
  Mesa-libEGL1 \
  libvulkan_radeon \
  libvulkan1

# Install AMD ROCm (for compute workloads)
sudo zypper addrepo --refresh \
  https://download.opensuse.org/repositories/science:/HPC/15.6/ rocm
sudo zypper install -y rocm-opencl

# Test GPU
glxinfo | grep "OpenGL renderer"
clinfo

# For NVIDIA GPUs
sudo zypper addrepo --refresh \
  https://download.nvidia.com/opensuse/leap/15.6 nvidia
sudo zypper install -y nvidia-driver-G06-kmp-default
nvidia-smi
```

### GPU Passthrough Troubleshooting

#### GPU Not Detected in VM

```bash
# On Proxmox host:
# 1. Verify GPU is bound to vfio-pci
lspci -k -s 09:00.0

# Expected output:
# Kernel driver in use: vfio-pci

# If showing amdgpu/nvidia instead:
echo "0000:09:00" > /sys/bus/pci/devices/0000:09:00/driver/unbind
echo "0000:09:00" > /sys/bus/pci/drivers/vfio-pci/bind

# 2. Check IOMMU groups
dmesg | grep -i vfio
```

#### VM Won't Boot with GPU

```bash
# Try these BIOS settings on Proxmox host:
# - Enable "Above 4G Decoding"
# - Enable "Re-Size BAR Support"
# - Disable "CSM" (Legacy Boot)

# In terraform.tfvars, try:
vm_hostpci0_pcie   = false  # Disable PCIe
vm_hostpci0_rombar = false  # Disable ROM BAR
```

#### NVIDIA Code 43 Error

```bash
# NVIDIA drivers detect KVM and refuse to work
# Add to terraform.tfvars:
vm_cpu_type = "host,hidden,kvm=off"

# Or update CPU args:
vm_kvm_arguments = "-cpu 'host,kvm=off,hv_vendor_id=proxmox'"
```

## USB Device Passthrough

### Identify USB Devices

```bash
# List all USB devices
lsusb

# Example output:
# Bus 001 Device 003: ID 046d:c328 Logitech, Inc. Corded Mouse M500
# Bus 004 Device 002: ID 413c:2113 Dell Computer Corp. KB216 Keyboard
# Bus 002 Device 005: ID 0951:1666 Kingston Technology DataTraveler 100 G3

# USB ID format: vendorID:productID
```

### Configure USB Passthrough

Update `terraform.tfvars`:

```hcl
# USB Device 1: Mouse
vm_usb_device_1_host = "046d:c328"  # Your mouse vendor:product
vm_usb_device_1_usb3 = false        # USB 2.0 sufficient for mouse

# USB Device 2: Keyboard
vm_usb_device_2_host = "413c:2113"  # Your keyboard vendor:product
vm_usb_device_2_usb3 = false        # USB 2.0 sufficient for keyboard

# USB Device 3: Storage device
vm_usb_device_3_host = "0951:1666"  # USB drive vendor:product
vm_usb_device_3_usb3 = true         # USB 3.0 for faster transfer

# USB Device 4: Additional (or leave empty)
vm_usb_device_4_host = ""           # Empty if not used
vm_usb_device_4_usb3 = false
```

**Alternative: Hub Port Format**

```hcl
# Use physical port instead of device ID
vm_usb_device_1_host = "1-4"      # Bus 1, Port 4
vm_usb_device_2_host = "4-2.3"    # Bus 4, Port 2, Subport 3
```

**Pros/Cons:**
- **Vendor:Product ID**: Works regardless of USB port, but affects all matching devices
- **Hub Port**: Specific physical port, but device must stay in same port

### Uncomment USB Blocks in main.tf

Edit `main.tf` and uncomment USB blocks (around line 425):

```terraform
# Uncomment these blocks:
usb {
  host = var.vm_usb_device_1_host
  usb3 = var.vm_usb_device_1_usb3
}
# ... (repeat for other USB devices)
```

### Apply Changes

```bash
tofu apply
```

### Verify USB Passthrough

```bash
# In VM, check USB devices
lsusb

# Should show your passed-through devices
# Bus 001 Device 002: ID 046d:c328 Logitech, Inc. Corded Mouse M500
```

## Configuration Variables

### Essential Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `proxmox_endpoint` | string | - | Proxmox API URL (https://ip:8006/) |
| `proxmox_api_token` | string | - | API token (user@realm!token=secret) |
| `proxmox_user` | string | - | SSH username for Proxmox |
| `proxmox_node_name` | string | "pve" | Proxmox node name |
| `vm_id` | number | 100 | Unique VM ID (100-999999999) |
| `vm_name` | string | "opensuseLeap15-6" | VM name |

### Hardware Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `vm_cpu_cores` | number | 2 | CPU cores (1-128) |
| `vm_cpu_type` | string | "x86-64-v2-AES" | CPU type (host, x86-64-v2-AES) |
| `vm_memory_dedicated` | number | 12288 | Dedicated RAM in MB |
| `vm_memory_floating` | number | 16384 | Max balloon RAM in MB |
| `vm_disk_size` | number | 50 | Disk size in GB (min 20) |
| `vm_disk_datastore_id` | string | "local-lvm" | Storage location |

### GPU Passthrough

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `vm_hostpci0_id` | string | "0000:0b:00" | GPU PCI ID |
| `vm_hostpci0_pcie` | bool | true | Enable PCIe |
| `vm_hostpci0_rombar` | bool | true | Enable ROM BAR |
| `vm_hostpci0_xvga` | bool | true | Primary VGA |
| `vm_hostpci4_id` | string | "0000:0c:00.1" | Audio PCI ID |

### USB Passthrough

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `vm_usb_device_1_host` | string | "212e:1534" | Device 1 ID |
| `vm_usb_device_1_usb3` | bool | false | Enable USB 3.0 |
| `vm_usb_device_2_host` | string | "1-4" | Device 2 ID |
| `vm_usb_device_2_usb3` | bool | false | Enable USB 3.0 |

### Cloud-Init

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `cloudinit_enabled` | bool | true | Enable cloud-init |
| `cloudinit_admin_username` | string | "admin" | Admin username |
| `ansible_ssh_key_path` | string | "~/.ssh/ansible_key.pub" | Ansible SSH key |
| `admin_ssh_key_path` | string | "~/.ssh/admin_key.pub" | Admin SSH key |
| `cloudinit_use_dhcp` | bool | true | Use DHCP |

See `variables.tf` for complete list of 100+ variables.

## Outputs

After deployment, view outputs:

```bash
# Display all outputs
tofu output

# Get specific output
tofu output vm_id
tofu output connection_info

# Export to JSON
tofu output -json > outputs.json
```

### Available Outputs

| Output | Description |
|--------|-------------|
| `vm_id` | VM identifier in Proxmox |
| `vm_name` | VM name |
| `vm_node` | Proxmox node hosting VM |
| `vm_ipv4_addresses` | IPv4 addresses (sensitive) |
| `vm_mac_addresses` | MAC addresses (sensitive) |
| `vm_cpu_cores` | Allocated CPU cores |
| `vm_memory_dedicated` | Dedicated memory in MB |
| `vm_gpu_pci_id` | GPU device ID |
| `vm_audio_pci_id` | Audio device ID |
| `connection_info` | Consolidated connection info |

## Known Issues

### 1. Disk Resize Error

**Symptom:**
```
Error: resizing disk: error waiting for VM disk resize: All attempts fail:
shrinking disks is not supported
```

**Cause**: Proxmox doesn't support shrinking disks. This error occurs when:
- VM disk is already larger than configured size
- Cloud image is larger than vm_disk_size
- Disk was manually resized in Proxmox GUI

**Solution:**

```hcl
# Option 1: Set disk size to current size or larger
vm_disk_size = 100  # Match or exceed current size

# Option 2: Ignore disk size changes in main.tf
lifecycle {
  ignore_changes = [disk[0].size]
}
```

Verify current disk size:
```bash
# On Proxmox host
qm config <vm_id> | grep scsi0
```

### 2. Cloud-Init Package Installation Failures

**Symptom**: Packages fail to install with "package not found" errors

**Cause**: openSUSE uses different package names than Debian/Ubuntu

**Solution**: The configuration uses correct openSUSE package names:
- ✅ `patterns-devel-base-devel_basis` (not `build-essential`)
- ✅ `net-tools-deprecated` (not `net-tools`)
- ✅ `dbus-1` (not `dbus-daemon`)

If you modify `cloud-init/user-config.yaml`, use openSUSE package names:
```bash
# Search for packages
zypper search <package-name>
```

### 3. Snippets Content Type Not Enabled

**Symptom**: 
```
Error: content type 'snippets' is not enabled for storage 'local'
```

**Solution**:
```bash
# On Proxmox host
pvesm set local --content iso,vztmpl,snippets

# Verify
pvesm status | grep snippets
```

### 4. QEMU Guest Agent Not Running

**Symptom**: VM IP address shows as "No IP assigned"

**Cause**: Guest agent not started yet (cloud-init still running or agent failed)

**Solution**:
```bash
# SSH to VM
ssh -i ~/.ssh/admin_key admin@<vm-ip>

# Check agent status
sudo systemctl status qemu-guest-agent

# If not running
sudo systemctl enable qemu-guest-agent
sudo systemctl start qemu-guest-agent

# On Proxmox host, check agent communication
qm agent <vm_id> ping
```

## Troubleshooting

### General Debugging

```bash
# Enable debug logging
export TF_LOG=DEBUG
tofu apply

# Check Proxmox task log
tail -f /var/log/pve/tasks/active

# View specific task details
cat /var/log/pve/tasks/<task-id>
```

### VM Won't Start

```bash
# Check VM status
qm status <vm_id>

# View VM configuration
qm config <vm_id>

# Try starting manually
qm start <vm_id>

# Check logs
journalctl -u pveproxy -f
```

### Network Issues

```bash
# In VM, check network interfaces
ip addr show

# Check routing
ip route show

# Test connectivity
ping 8.8.8.8

# If DHCP not working, check cloud-init network config
sudo cat /etc/netplan/*.yaml  # Ubuntu-based
sudo cat /etc/sysconfig/network-scripts/ifcfg-*  # openSUSE
```

### State File Issues

```bash
# Backup state
cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d)

# Refresh state from actual infrastructure
tofu refresh

# If corrupted, restore from backup
cp terraform.tfstate.backup terraform.tfstate

# Re-import resource if needed
tofu import proxmox_virtual_environment_vm.opensuseLeap[0] <vm_id>
```

## Performance Tuning

### CPU Optimization

```hcl
# Maximum performance
vm_cpu_type = "host"  # Expose all host CPU features

# For Windows guests, add Hyper-V enlightenments
vm_kvm_arguments = "-cpu 'host,hv_ipi,hv_relaxed,hv_reset,hv_runtime,hv_spinlocks=0x1fff,hv_stimer,hv_synic,hv_time,hv_vapic,hv_vpindex'"
```

### Memory Optimization

```hcl
# Dedicated memory (no ballooning)
vm_memory_dedicated = 24576
vm_memory_floating  = 24576  # Same as dedicated

# With ballooning (flexible)
vm_memory_dedicated = 16384  # Minimum guaranteed
vm_memory_floating  = 24576  # Maximum allowed
```

### Disk Performance

```hcl
# Maximum performance
vm_disk_aio      = "io_uring"   # Latest async I/O
vm_disk_cache    = "writeback"  # Write caching
vm_disk_iothread = true         # Dedicated thread
vm_disk_ssd      = true         # Enable TRIM
vm_disk_discard  = "on"         # Pass TRIM to storage
vm_disk_file_format = "raw"     # Raw format (not qcow2)
```

### Network Performance

```hcl
# VirtIO with multiqueue
vm_network_model  = "virtio"
vm_network_queues = 8  # Match CPU cores
```

## Security Considerations

### API Token Security

**Never commit API tokens to version control:**

```bash
# Use environment variables
export TF_VAR_proxmox_api_token="terraform@pve!token=secret"

# Add to .gitignore
echo "terraform.tfvars" >> .gitignore
echo "*.tfstate*" >> .gitignore
```

**Rotate tokens regularly:**
```bash
# In Proxmox, revoke old token and create new one
# Update terraform.tfvars or environment variable
```

### SSH Key Security

```bash
# Proper permissions
chmod 600 ~/.ssh/ansible_key ~/.ssh/admin_key
chmod 644 ~/.ssh/ansible_key.pub ~/.ssh/admin_key.pub

# Use passphrases for admin keys
ssh-keygen -t ed25519 -f ~/.ssh/admin_key -C "admin@homelab"
# Enter passphrase when prompted

# Use ssh-agent
eval $(ssh-agent)
ssh-add ~/.ssh/admin_key
```

### State File Encryption

State files contain sensitive data. This configuration includes encryption:

```hcl
# In encryption.tf
terraform {
  encryption {
    key_provider "pbkdf2" "generated_passphrase" {
      passphrase = file(var.passphrase)
      iterations = 600000
      key_length = 32
    }
    method "aes_gcm" "default_method" {
      keys = key_provider.pbkdf2.generated_passphrase
    }
    state {
      method   = method.aes_gcm.default_method
      enforced = true
    }
  }
}
```

**Setup:**
```bash
# Create passphrase file
echo "your-strong-passphrase-min-16-chars" > ~/.ssh/state_passphrase
chmod 600 ~/.ssh/state_passphrase

# Update terraform.tfvars
passphrase = "~/.ssh/state_passphrase"
```

### Network Security

```bash
# In cloud-init, SSH is hardened:
# - Root login disabled
# - Password authentication disabled
# - Firewall enabled with SSH only

# Additional hardening (in VM):
sudo firewall-cmd --set-default-zone=drop
sudo firewall-cmd --zone=drop --add-service=ssh --permanent
sudo firewall-cmd --reload
```

## Maintenance

### Regular Updates

```bash
# Update OpenTofu providers
tofu init -upgrade

# Check for configuration drift
tofu plan

# Update VM packages (in VM)
ssh -i ~/.ssh/admin_key admin@<vm-ip>
sudo zypper update -y
```

### Backup

```bash
# Backup state files
cp terraform.tfstate s3://my-backups/tfstate-$(date +%Y%m%d).json

# Create VM snapshot
qm snapshot <vm_id> pre-update-$(date +%Y%m%d)

# Proxmox backup
vzdump <vm_id> --mode snapshot --storage backup-storage
```

### Scaling Resources

```bash
# Update terraform.tfvars
vm_cpu_cores = 16
vm_memory_dedicated = 49152

# Apply changes (may require VM restart)
tofu apply
```

## References

### Official Documentation

- [OpenTofu Documentation](https://opentofu.org/docs/)
- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
- [Proxmox Terraform Provider](https://github.com/bpg/terraform-provider-proxmox)
- [OpenSUSE Leap Documentation](https://documentation.suse.com/)
- [Cloud-Init Documentation](https://cloudinit.readthedocs.io/)

### GPU Passthrough Guides

- [Proxmox GPU Passthrough](https://pve.proxmox.com/wiki/PCI_Passthrough)
- [AMD GPU Passthrough](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)
- [NVIDIA GPU Passthrough](https://www.reddit.com/r/VFIO/)

### Community Resources

- [Proxmox Forum](https://forum.proxmox.com/)
- [/r/Proxmox](https://www.reddit.com/r/Proxmox/)
- [/r/VFIO](https://www.reddit.com/r/VFIO/)

## License

This configuration is provided under the MIT License.

## Contributing

Issues, questions, and improvements are welcome!

1. Check [Known Issues](#known-issues) and [Troubleshooting](#troubleshooting)
2. Review Proxmox logs: `tail -f /var/log/pve/tasks/active`
3. Enable debug logging: `export TF_LOG=DEBUG`
4. Report with full output and configuration (sanitize sensitive data)

---

**Version**: 1.0.0  
**Last Updated**: December 18, 2024  
**OpenTofu Version**: 1.6.0+  
**Proxmox Version**: 8.x+  
**OpenSUSE Version**: Leap 15.6
