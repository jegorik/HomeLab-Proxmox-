# Ansible Playbooks & Configurations

[![Ansible](https://img.shields.io/badge/Ansible-2.10+-red?style=flat&logo=ansible)](https://www.ansible.com/)
[![Semaphore](https://img.shields.io/badge/Semaphore_UI-Compatible-blue?style=flat)](https://semaphoreui.com/)

Ansible playbooks and configurations for HomeLab infrastructure management.

## 📁 Structure

```text
ansible/
├── ansible.cfg              # Global Ansible configuration
├── inventory.yml.example    # Example inventory file
├── group_vars/              # Group-level variables
│   └── all.yml.example      # Variables for all hosts
│
├── playbooks/               # Playbooks organized by category
│   ├── proxmox/             # Proxmox host management
│   ├── maintenance/         # System maintenance tasks
│   └── debug/               # Debugging and testing
│
└── roles/                   # Reusable Ansible roles (future)
```

## 🚀 Quick Start

### 1. Setup Inventory

```bash
cp inventory.yml.example inventory.yml
# Edit inventory.yml with your hosts
```

### 2. Setup Group Variables

```bash
cp group_vars/all.yml.example group_vars/all.yml
# Edit group_vars/all.yml with your settings
```

### 3. Test Connection

```bash
ansible-playbook playbooks/debug/test_connection.yml
```

## 📋 Available Playbooks

| Category | Playbook | Description |
|----------|----------|-------------|
| **proxmox** | `apply_fcos_ignition.yml` | Apply Ignition config to Fedora CoreOS VM |
| **maintenance** | `update_packages.yml` | Update packages on all systems |
| **debug** | `test_connection.yml` | Test SSH connectivity to hosts |

## 🔧 Configuration

### ansible.cfg

The `ansible.cfg` file is pre-configured for HomeLab use:

- **Timeouts**: 30s for SSH, prevents infinite hangs
- **Pipelining**: Enabled for faster execution
- **Host key checking**: Disabled (HomeLab only!)
- **YAML output**: Clean, readable output format

### Inventory Groups

Recommended inventory groups:

```yaml
all:
  children:
    proxmox:     # Proxmox VE hosts
    vms:         # Virtual machines
    lxc:         # LXC containers
    debian:      # Debian/Ubuntu systems
    redhat:      # RHEL/CentOS/Fedora systems
```

## 🔌 Semaphore UI Integration

All playbooks are designed for Semaphore UI:

1. **Repository**: Point to this repo
2. **Playbook Path**: `scripts/ansible/playbooks/<category>/<playbook>.yml`
3. **Inventory**: Use `scripts/ansible/inventory.yml`
4. **Environment**: Set variables via Semaphore environment

### Example Task Templates

| Task Name | Playbook Path |
|-----------|---------------|
| Update All Systems | `scripts/ansible/playbooks/maintenance/update_packages.yml` |
| Test Connectivity | `scripts/ansible/playbooks/debug/test_connection.yml` |
| Apply FCOS Ignition | `scripts/ansible/playbooks/proxmox/apply_fcos_ignition.yml` |

## 📝 Adding New Playbooks

1. Choose appropriate category folder
2. Create playbook with header documentation
3. Add entry to this README
4. Test locally before committing

---

**Author**: jegorik  
**Last Updated**: December 2025
