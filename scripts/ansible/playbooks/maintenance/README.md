# System Maintenance Playbooks

Playbooks for routine system maintenance tasks across all managed hosts.

## 📋 Available Playbooks

### update_packages.yml

**Purpose**: Update system packages on multiple Linux distributions.

**Supported Distributions**:

- Debian / Ubuntu (APT)
- RHEL / CentOS / Fedora / Rocky (DNF/YUM)
- OpenSUSE / SLES (Zypper)

**Features**:

- ✅ Multi-distribution support
- ✅ Conditional reboot when required
- ✅ Package cache cleanup
- ✅ Detailed progress output
- ✅ Idempotent execution

**Usage**:

```bash
# Update all hosts
ansible-playbook update_packages.yml

# Update specific group
ansible-playbook update_packages.yml -l vms

# Update single host
ansible-playbook update_packages.yml -l ubuntu-server

# Skip automatic reboot
ansible-playbook update_packages.yml --skip-tags reboot

# Dry run (check mode)
ansible-playbook update_packages.yml --check
```

**Variables**:

| Variable | Default | Description |
|----------|---------|-------------|
| `reboot_enabled` | `true` | Auto-reboot when kernel updates require it |
| `reboot_timeout` | `300` | Max wait time for reboot (seconds) |
| `clean_packages` | `true` | Remove unused packages and clear cache |

**Tags**:

| Tag | Description |
|-----|-------------|
| `update` | Package update tasks |
| `cleanup` | Package cleanup tasks |
| `reboot` | Reboot tasks |
| `debian` | Debian/Ubuntu specific |
| `redhat` | RHEL/CentOS/Fedora specific |
| `suse` | OpenSUSE/SLES specific |

**Example Output**:

```text
TASK [Display target system information] ***************************************
ok: [ubuntu-server] => 
  msg: |-
    Host: ubuntu-server
    OS: Ubuntu 22.04
    Kernel: 5.15.0-91-generic
    Architecture: x86_64

TASK [[Debian/Ubuntu] Upgrade all packages] ************************************
changed: [ubuntu-server]
```

## 🔧 Adding New Maintenance Playbooks

Ideas for additional maintenance playbooks:

- `cleanup_logs.yml` - Rotate and clean old log files
- `update_certificates.yml` - Renew SSL/TLS certificates
- `backup_configs.yml` - Backup configuration files
- `check_disk_space.yml` - Alert on low disk space
- `security_audit.yml` - Run security checks

## 📅 Scheduling with Semaphore UI

Create scheduled tasks in Semaphore UI:

1. **Daily**: `test_connection.yml` - Verify all hosts accessible
2. **Weekly**: `update_packages.yml` - Keep systems updated
3. **Monthly**: Security audits, certificate renewals
