# Debug & Testing Playbooks

Playbooks for debugging connectivity and testing Ansible configurations.

## 📋 Available Playbooks

### test_connection.yml

**Purpose**: Verify SSH connectivity to all hosts before running other playbooks.

**Use Case**: 
- Troubleshoot connection issues
- Validate inventory configuration
- Quick health check of managed hosts

**Features**:
- Fast execution (minimal timeouts)
- No privilege escalation required
- Shows system info on success
- Clear success/failure messages

**Usage**:

```bash
# Test all hosts
ansible-playbook test_connection.yml

# Test specific group
ansible-playbook test_connection.yml -l proxmox

# Test single host
ansible-playbook test_connection.yml -l ubuntu-server

# Verbose output for debugging
ansible-playbook test_connection.yml -vvv
```

**Output Examples**:

Success:
```
TASK [Display ping result] *****************************************************
ok: [ubuntu-server] => 
  msg: ✅ SSH connection to ubuntu-server successful!

TASK [Display system info] *****************************************************
ok: [ubuntu-server] => 
  msg: 'System: Linux ubuntu-server 5.15.0-91-generic #101-Ubuntu SMP x86_64 GNU/Linux'
```

Failure:
```
TASK [Ping host (SSH connectivity test)] ***************************************
fatal: [unreachable-host]: UNREACHABLE! => {
    "msg": "Failed to connect to the host via ssh: ssh: connect to host 192.168.0.100 port 22: Connection timed out",
    "unreachable": true
}
```

## 🔧 Troubleshooting Guide

### Connection Issues

| Error | Cause | Solution |
|-------|-------|----------|
| `Connection timed out` | Host unreachable | Check IP, firewall, host is running |
| `Connection refused` | SSH not running | Start SSH service on host |
| `Permission denied` | Auth failed | Check SSH key, ansible_user |
| `Host key verification` | New/changed host | Add to known_hosts or disable checking |

### Quick Fixes

```bash
# Test raw SSH connection
ssh ansible@192.168.0.100

# Check if host is reachable
ping 192.168.0.100

# Verify SSH service
nc -zv 192.168.0.100 22

# Run with verbose output
ansible -i inventory.yml all -m ping -vvv
```

## 📝 Adding New Debug Playbooks

Ideas for additional debug playbooks:

- `check_sudo.yml` - Verify sudo access works
- `gather_facts.yml` - Collect detailed system facts
- `network_test.yml` - Test network connectivity between hosts
- `service_status.yml` - Check status of critical services
