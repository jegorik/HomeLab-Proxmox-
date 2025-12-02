# Ubuntu Server VM - Terraform/OpenTofu Configuration

This Terraform/OpenTofu configuration provisions Ubuntu Server virtual machines
on Proxmox VE using cloud-init for automated initial configuration.

## Features

- **Cloud Image Deployment**: Downloads and uses official Ubuntu cloud images
- **Cloud-Init Integration**: Automated VM initialization with user accounts and SSH keys
- **TPM 2.0 Support**: Modern security features enabled
- **QEMU Guest Agent**: Enhanced VM management and IP reporting
- **Remote State**: PostgreSQL backend for team collaboration
- **Security**: Generated passwords, SSH key authentication, validation rules

## Prerequisites

### Proxmox VE Requirements

- Proxmox VE 8.x or later
- API token with the following permissions:
  - `Datastore.AllocateSpace`
  - `Datastore.AllocateTemplate`
  - `Datastore.Audit`
  - `SDN.Use`
  - `Sys.Audit`
  - `VM.Allocate`
  - `VM.Audit`
  - `VM.Clone`
  - `VM.Config.*`
  - `VM.PowerMgmt`

### Local Requirements

- OpenTofu >= 1.6.0 or Terraform >= 1.5.0
- SSH key pair (`~/.ssh/id_rsa.pub` by default)
- Network access to Proxmox API

### Backend Requirements (Optional)

For remote state storage:

- PostgreSQL 12+ database
- Database credentials in `pg.backend.conf`

## Quick Start

### 1. Clone and Configure

```bash
cd terraform/ubuntu-server

# Copy and edit the variables file
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 2. Configure Backend (Optional)

For local state, comment out the backend block in `backend.tf`.

For PostgreSQL backend, create `pg.backend.conf`:

```ini
conn_str = "postgres://user:password@host:5432/database?sslmode=disable"
```

### 3. Initialize and Apply

```bash
# Initialize with PostgreSQL backend
tofu init -backend-config=pg.backend.conf

# Or initialize with local state
tofu init

# Review planned changes
tofu plan

# Apply infrastructure
tofu apply
```

### 4. Access the VM

```bash
# Get the VM password
tofu output -raw ubuntu_vm_password

# SSH to the VM (IP from Proxmox console or QEMU guest agent)
ssh ubuntu@<vm-ip>
```

## File Structure

| File | Description |
|------|-------------|
| `main.tf` | Main VM resource definition and cloud image download |
| `variables.tf` | Input variable definitions with validations |
| `outputs.tf` | Output values (password, SSH key path, IP addresses) |
| `providers.tf` | Provider configuration (bpg/proxmox v0.88.0) |
| `backend.tf` | PostgreSQL state backend configuration |
| `terraform.tfvars` | Variable values (not committed - contains secrets) |
| `pg.backend.conf` | PostgreSQL connection string (not committed) |

## Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `proxmox_endpoint` | Proxmox API URL | - |
| `proxmox_api_token` | API token | - |
| `vm_id` | Unique VM ID | 100 |
| `vm_name` | VM hostname | ubuntu-server |
| `vm_cpu_core` | CPU cores | 2 |
| `vm_memory_dedicated` | Memory in MB | 2048 |
| `vm_boot_disk_size` | Disk size in GB | 15 |
| `ssh_key_path` | SSH public key path | ~/.ssh/id_rsa.pub |

See `variables.tf` for the complete list with descriptions.

## Security Considerations

1. **Never commit `terraform.tfvars`** - Contains API tokens
2. **Never commit `pg.backend.conf`** - Contains database credentials
3. **Rotate API tokens** regularly
4. **Use HTTPS** with valid certificates in production (`connection_option_insecure = false`)
5. **Use environment variables** for sensitive values in CI/CD:

```bash
export TF_VAR_proxmox_api_token="user@pam!token=secret"
```

## Troubleshooting

### VM IP Not Shown

The QEMU Guest Agent needs to be installed inside the VM:

```bash
sudo apt update && sudo apt install qemu-guest-agent -y
sudo systemctl enable qemu-guest-agent
sudo systemctl start qemu-guest-agent
```

### Cloud Image Download Fails

Verify the `vm_download_img_url` is accessible and uses HTTPS.

### SSH Connection Refused

1. Verify the SSH key path in `terraform.tfvars`
2. Check cloud-init logs: `sudo cat /var/log/cloud-init-output.log`
3. Ensure the VM's network is configured correctly

## Provider Documentation

- [bpg/proxmox Provider](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
- [Proxmox VE API](https://pve.proxmox.com/pve-docs/api-viewer/)

## License

This configuration is provided as-is. Verify licensing for Ubuntu cloud images
and any components you deploy in production.
