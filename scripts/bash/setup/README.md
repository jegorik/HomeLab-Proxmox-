# Setup Scripts

Scripts for initial host configuration and preparation for Ansible management.

## 📋 Scripts

### ansible_user_setup.sh

Creates a dedicated Ansible automation user with:
- SSH public key authentication
- Passwordless sudo access
- Proper home directory and shell

See [parent README](../README.md) for detailed usage.

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
| `ansible_user_setup.sh` | Main setup script | Tracked |
| `.env.example` | Template for environment | Tracked |
| `.env` | Your actual config | **Ignored** |

## ⚠️ Prerequisites

On target host:
- Root or sudo access for initial run
- SSH server running
- Internet access (for package installation if needed)
