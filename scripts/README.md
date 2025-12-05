# Scripts - HomeLab Automation Utilities

This directory contains automation scripts for managing and configuring
hosts in the Proxmox-based home laboratory environment.

## Directory Structure

```text
scripts/
└── bash/
    ├── ansible_user_setup.sh   # Ansible user provisioning script
    ├── .env                    # Environment configuration (not committed)
    └── .env.example            # Example environment file
```

## Available Scripts

### [`bash/ansible_user_setup.sh`](bash/ansible_user_setup.sh)

Creates and configures a dedicated Ansible automation user on target Linux hosts.
This prepares systems for management by Ansible/Semaphore UI.

**Features:**

- Creates user account with SSH key authentication
- Configures passwordless sudo access
- Supports Debian/Ubuntu (sudo group) and RHEL/CentOS (wheel group)
- Idempotent - safe to run multiple times
- Validates all configurations after setup
- Color-coded output for easy reading
- Dry-run mode for testing

**Quick Start:**

```bash
# 1. Copy and configure environment file
cd scripts/bash
cp .env.example .env
nano .env  # Add your SSH public key

# 2. Copy script to target host
scp ansible_user_setup.sh .env user@target-host:/tmp/

# 3. Run on target host
ssh user@target-host
sudo /tmp/ansible_user_setup.sh /tmp/.env
```

**Usage Options:**

```bash
# With .env file in same directory
sudo ./ansible_user_setup.sh

# With custom environment file
sudo ./ansible_user_setup.sh /path/to/custom.env

# Dry-run mode (no changes)
sudo ./ansible_user_setup.sh --dry-run

# Show help
./ansible_user_setup.sh --help
```

**Environment Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `ANSIBLE_USER` | Username to create | `ansible` |
| `ANSIBLE_SSH_KEY` | SSH public key (required) | - |
| `ANSIBLE_SHELL` | User shell | `/bin/bash` |
| `ANSIBLE_SUDO` | Enable passwordless sudo | `true` |

## Security Considerations

1. **Never commit `.env` files** - They contain sensitive SSH keys
2. **Restrict file permissions** - `chmod 600 .env`
3. **Use SSH key authentication** - Passwords are not configured
4. **Audit sudo access** - Passwordless sudo is a security trade-off for automation

## Use Cases

### Preparing Hosts for Semaphore UI

[Semaphore](https://semaphore.run/) is a modern UI for Ansible. This script
prepares target hosts with the SSH key from Semaphore:

1. Generate SSH key pair in Semaphore UI (Key Store)
2. Copy the public key to `.env` file
3. Run script on each target host
4. Add hosts to Semaphore inventory

### Bulk Host Provisioning

Use with `pdsh` or Ansible itself for bulk provisioning:

```bash
# Using pdsh
pdsh -w host[1-10] 'sudo bash -s' < ansible_user_setup.sh

# Using Ansible (bootstrap playbook)
ansible all -m script -a "ansible_user_setup.sh" --become
```

## Contributing

When adding new scripts:

1. Include comprehensive docstring/header comments
2. Use `set -euo pipefail` for strict error handling
3. Support environment variables for configuration
4. Add `.env.example` template if needed
5. Update this README with usage documentation

## License

These scripts are provided as-is for homelab use. Review and test
before using in production environments.
