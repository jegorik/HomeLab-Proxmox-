# Ansible Playbooks - HomeLab Automation

This directory contains Ansible playbooks for managing and maintaining
hosts in the Proxmox-based home laboratory environment.

## Available Playbooks

### [`update_vm_packages.yml`](update_vm_packages.yml)

Updates system packages on Debian/Ubuntu and RHEL/CentOS/Fedora hosts with
automatic reboot support when kernel updates require it.

**Features:**

- Multi-distribution support (Debian, Ubuntu, RHEL, CentOS, Fedora, Rocky Linux)
- Conditional reboot only when required
- Automatic cleanup of unused packages and cache
- Detailed output with host information
- Idempotent execution (safe to run multiple times)
- Tags for selective task execution

**Quick Start:**

```bash
# Update all hosts in inventory
ansible-playbook -i inventory.yml update_vm_packages.yml

# Update specific host group
ansible-playbook -i inventory.yml update_vm_packages.yml -l webservers

# Update single host
ansible-playbook -i inventory.yml update_vm_packages.yml -l hostname

# Dry run (check what would change)
ansible-playbook -i inventory.yml update_vm_packages.yml --check

# Skip automatic reboot
ansible-playbook -i inventory.yml update_vm_packages.yml --skip-tags reboot

# Only run cleanup tasks
ansible-playbook -i inventory.yml update_vm_packages.yml --tags cleanup
```

**Available Tags:**

| Tag | Description |
|-----|-------------|
| `update` | Package update tasks |
| `cleanup` | Package cleanup and cache clear |
| `reboot` | Reboot related tasks |
| `debian` | Debian/Ubuntu specific tasks |
| `redhat` | RHEL/CentOS/Fedora specific tasks |

**Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `reboot_enabled` | Enable automatic reboot when required | `true` |
| `reboot_timeout` | Max seconds to wait for reboot | `300` |
| `clean_packages` | Remove unused packages and clear cache | `true` |

Override variables at runtime:

```bash
ansible-playbook -i inventory.yml update_vm_packages.yml -e "reboot_enabled=false"
```

## Inventory Examples

### Simple inventory (`inventory.yml`)

```yaml
all:
  children:
    proxmox:
      hosts:
        pve:
          ansible_host: 192.168.0.204
    
    vms:
      hosts:
        ubuntu-server:
          ansible_host: 192.168.0.100
        grafana:
          ansible_host: 192.168.0.202
    
    lxc:
      hosts:
        grafana:
          ansible_host: 192.168.0.202

  vars:
    ansible_user: ansible
    ansible_become: true
    ansible_python_interpreter: /usr/bin/python3
```

### Group variables (`group_vars/all.yml`)

```yaml
# Default settings for all hosts
ansible_user: ansible
ansible_become: true
ansible_ssh_private_key_file: ~/.ssh/ansible_key

# Package update settings
reboot_enabled: true
reboot_timeout: 300
clean_packages: true
```

## Directory Structure

```text
ansible_playbooks/
├── README.md                    # This file
├── update_vm_packages.yml       # System update playbook
├── inventory.yml.example        # Example inventory file
└── group_vars/                  # Group variables (optional)
    └── all.yml.example          # Example group vars
```

## Integration with Semaphore UI

These playbooks are designed to work with [Semaphore](https://semaphoreui.com/),
a modern web UI for Ansible:

1. Add this repository as a Project in Semaphore
2. Configure inventory in Semaphore (or use the repository inventory)
3. Create a Task Template pointing to the playbook
4. Run manually or schedule periodic execution

### Recommended Semaphore Schedule

For production environments, schedule system updates during maintenance windows:

- **Weekly updates**: Every Sunday at 2:00 AM
- **Security updates**: Daily at 3:00 AM (with `--tags update --skip-tags reboot`)

## Requirements

### Control Node (Ansible/Semaphore)

- Ansible >= 2.12
- Python >= 3.8
- SSH access to target hosts

### Target Hosts

- SSH server running
- Python 3.x installed
- Ansible user with sudo privileges (see `bash/ansible_user_setup.sh`)

## Troubleshooting

### Connection Refused

```bash
# Test SSH connection
ssh -i ~/.ssh/ansible_key ansible@target-host

# Check if ansible user exists
ansible all -i inventory.yml -m ping
```

### Permission Denied

Ensure the ansible user has passwordless sudo:

```bash
# On target host
sudo visudo -f /etc/sudoers.d/ansible
# Should contain: ansible ALL=(ALL) NOPASSWD:ALL
```

### Reboot Timeout

Increase timeout for slow systems:

```bash
ansible-playbook -i inventory.yml update_vm_packages.yml -e "reboot_timeout=600"
```

## Security Considerations

1. **Use SSH keys** - Never use password authentication
2. **Limit sudo scope** - Consider limiting sudo to specific commands in production
3. **Audit updates** - Review what packages are being updated in check mode first
4. **Schedule wisely** - Run updates during maintenance windows
5. **Test first** - Use `--check` mode before applying to production

## License

These playbooks are provided as-is for homelab use. Review and test
before using in production environments.
