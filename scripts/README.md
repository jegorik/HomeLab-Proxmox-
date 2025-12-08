# HomeLab Scripts & Automation Tools

[![Ansible](https://img.shields.io/badge/Ansible-2.10+-red?style=flat&logo=ansible)](https://www.ansible.com/)
[![Bash](https://img.shields.io/badge/Bash-5.0+-green?style=flat&logo=gnubash)](https://www.gnu.org/software/bash/)

Collection of reusable automation scripts for HomeLab infrastructure management.

## 📁 Structure

```text
scripts/
├── ansible/                 # Ansible playbooks & configurations
│   ├── ansible.cfg          # Global Ansible config
│   ├── inventory.yml.example
│   ├── group_vars/          # Group variables
│   └── playbooks/           # Playbooks by category
│       ├── proxmox/         # Proxmox host management
│       ├── maintenance/     # System maintenance
│       └── debug/           # Testing & debugging
│
└── bash/                    # Shell scripts
    └── setup/               # Initial setup scripts
```

## 🚀 Quick Start

### Ansible

```bash
cd ansible

# 1. Setup inventory
cp inventory.yml.example inventory.yml
nano inventory.yml

# 2. Test connectivity
ansible-playbook playbooks/debug/test_connection.yml

# 3. Run maintenance
ansible-playbook playbooks/maintenance/update_packages.yml
```

### Bash

```bash
cd bash/setup

# 1. Configure environment
cp .env.example .env
nano .env  # Add your SSH key

# 2. Deploy to new host
scp ansible_user_setup.sh .env root@newhost:/tmp/
ssh root@newhost "bash /tmp/ansible_user_setup.sh /tmp/.env"
```

## 📋 Available Tools

### Ansible Playbooks

| Category | Playbook | Description |
|----------|----------|-------------|
| proxmox | `apply_fcos_ignition.yml` | Apply Ignition to Fedora CoreOS VM |
| maintenance | `update_packages.yml` | Update packages (multi-distro) |
| debug | `test_connection.yml` | Test SSH connectivity |

### Bash Scripts

| Category | Script | Description |
|----------|--------|-------------|
| setup | `ansible_user_setup.sh` | Create Ansible user on hosts |

## 🔌 Integration

### Semaphore UI

All scripts designed for Semaphore UI integration:

- **Playbook paths**: `scripts/ansible/playbooks/<category>/<name>.yml`
- **Inventory**: `scripts/ansible/inventory.yml`
- **Variables**: Via Semaphore environment or `group_vars/`

### OpenTofu / Terraform

Some playbooks work with OpenTofu outputs:

```bash
# Example: Fedora CoreOS deployment
tofu -chdir=terraform/fedora_core apply
ansible-playbook scripts/ansible/playbooks/proxmox/apply_fcos_ignition.yml \
  -e @terraform/fedora_core/generated/vm-ansible-vars.yml
```

## 📝 Contributing

When adding new scripts:

1. Choose appropriate category folder
2. Include comprehensive header documentation
3. Add README entry
4. Test before committing

---

See individual READMEs in each folder for detailed documentation.
