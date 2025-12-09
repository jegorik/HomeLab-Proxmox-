# Bash Scripts

Shell scripts for system setup and automation tasks.

## 📁 Structure

```text
bash/
├── setup/                          # Initial setup scripts
│   ├── ansible_user_setup.sh       # Create Ansible automation user
│   ├── proxmox_fcos_storage_setup.sh # Setup FCOS storage on Proxmox
│   ├── .env.example                # Example environment variables
│   └── .env                        # Your environment (gitignored)
│
└── (future categories...)
```

## 📋 Available Scripts

### setup/ansible_user_setup.sh

**Purpose**: Create and configure a dedicated Ansible automation user on target hosts.

**Features**:

- Creates user with SSH key authentication
- Configures passwordless sudo
- Supports Debian/Ubuntu and RHEL/CentOS
- Idempotent - safe to run multiple times
- Validates configuration after setup

### setup/proxmox_fcos_storage_setup.sh

**Purpose**: One-time setup for Fedora CoreOS deployment on Proxmox VE.

**Features**:

- Creates `/var/coreos/{images,snippets}` directory structure
- Registers `coreos` storage in Proxmox (`pvesm add dir`)
- Downloads FCOS image via `coreos-installer` (with podman/docker fallback)
- Validates storage configuration
- Color-coded output and comprehensive error handling
- No configuration needed - fully automated

**Usage**:

```bash
# Preview changes (dry-run)
ssh root@proxmox-host 'bash -s -- --dry-run' < scripts/bash/setup/proxmox_fcos_storage_setup.sh

# Run on Proxmox host
ssh root@proxmox-host < scripts/bash/setup/proxmox_fcos_storage_setup.sh

# Or copy and run locally
scp scripts/bash/setup/proxmox_fcos_storage_setup.sh root@proxmox:/tmp/
ssh root@proxmox "bash /tmp/proxmox_fcos_storage_setup.sh"

# Get help
ssh root@proxmox-host 'bash -s -- --help' < scripts/bash/setup/proxmox_fcos_storage_setup.sh
```

**Options**:

- `--dry-run, -n` - Preview changes without making them
- `--help, -h` - Show usage information

**Usage**:

```bash
# 1. Copy and edit environment file
cp setup/.env.example setup/.env
# Edit .env with your SSH public key

# 2. Copy script to target host
scp setup/ansible_user_setup.sh setup/.env user@target-host:/tmp/

# 3. Run on target host
ssh user@target-host
sudo /tmp/ansible_user_setup.sh /tmp/.env

# 4. Test connection
ssh ansible@target-host
```

**Environment Variables**:

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ANSIBLE_USER` | ❌ | `ansible` | Username to create |
| `ANSIBLE_SSH_KEY` | ✅ | - | SSH public key |
| `ANSIBLE_SHELL` | ❌ | `/bin/bash` | User shell |
| `ANSIBLE_SUDO` | ❌ | `true` | Enable passwordless sudo |

**Example .env**:

```bash
ANSIBLE_USER="ansible"
ANSIBLE_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... ansible@homelab"
ANSIBLE_SHELL="/bin/bash"
ANSIBLE_SUDO="true"
```

## 🔒 Security Notes

- `.env` files are gitignored - never commit credentials
- SSH key authentication only (no passwords)
- Passwordless sudo is for automation only
- Run only on trusted internal networks

## 📝 Adding New Scripts

When adding new bash scripts:

1. Choose/create appropriate category folder
2. Add comprehensive header documentation
3. Support `.env` files for configuration
4. Make scripts idempotent when possible
5. Add validation and error handling
6. Update this README

### Script Categories (Future)

- `setup/` - Initial host configuration
- `backup/` - Backup scripts
- `monitoring/` - Health checks
- `cleanup/` - Maintenance scripts
