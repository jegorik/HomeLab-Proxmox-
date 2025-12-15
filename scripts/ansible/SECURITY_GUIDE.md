# Ansible Playbook Security Guide

## Overview

This guide covers security best practices for using the `update_packages.yml` playbook safely in production and development environments.

## ⚠️ Security Concerns

### 1. **Automatic GPG Key Import** (HIGH RISK)

**Issue**: The playbook uses `--gpg-auto-import-keys` which automatically trusts new GPG keys without manual verification.

```bash
zypper --gpg-auto-import-keys --non-interactive update
```

**Why it's risky**:

- Could accept keys from compromised repositories
- No opportunity to verify key fingerprints
- Suitable only for isolated homelab environments

**Safe alternatives for production**:

- Manually import trusted GPG keys beforehand
- Use repository mirrors with pre-verified keys
- Disable untrusted repositories before running playbook

**Mitigation**:

```bash
# Before running playbook:
zypper ar <trusted-repo-url> <name>  # Add only trusted repos
zypper rr untrusted-repo             # Remove problematic repos
```

---

### 2. **Automatic Reboot** (MEDIUM RISK)

**Old default**: `reboot_enabled: true` ❌ **UNSAFE**

**New default**: `reboot_enabled: false` ✅ **SAFE**

**Why automatic reboot is risky**:

- Production services interrupted unexpectedly
- Dependent systems may fail if one host reboots
- No chance to coordinate maintenance window

**Safe usage**:

```bash
# Development/Staging only:
ansible-playbook -i inventory.yml playbooks/maintenance/update_packages.yml \
  -e reboot_enabled=true

# Production - schedule reboots separately:
ansible-playbook -i inventory.yml playbooks/maintenance/update_packages.yml \
  -e reboot_enabled=false
# Then manually reboot during maintenance window
```

---

### 3. **Lack of Approval Gate** (MEDIUM RISK)

**New feature**: Manual approval prompt in production mode

The playbook now requires explicit confirmation before making changes:

```bash
# Check mode (safe, no changes):
ansible-playbook -i inventory.yml playbooks/maintenance/update_packages.yml --check

# Will prompt for approval:
ansible-playbook -i inventory.yml playbooks/maintenance/update_packages.yml

# Skip prompt (use only with auto_approve_updates=true):
ansible-playbook -i inventory.yml playbooks/maintenance/update_packages.yml \
  -e auto_approve_updates=true
```

**Best practice workflow**:

1. Run with `--check` flag first
2. Review the output carefully
3. If safe, run without `--check`
4. Confirm the prompt
5. Monitor the execution

---

### 4. **No Backup/Rollback** (MEDIUM RISK)

**Action needed**: Create system snapshots before major updates

For Proxmox/LXC environments:

```bash
# Create snapshot before playbook
pct snapshot <CTID> pre-update-$(date +%Y%m%d)

# Then run playbook
ansible-playbook -i inventory.yml playbooks/maintenance/update_packages.yml --check
```

For traditional VMs:

- Use LVM snapshots
- Create VM snapshots
- Use backup tools (Bacula, Duplicati, etc.)

---

### 5. **Blanket Sudo Access** (LOW RISK)

The playbook uses `become: true` for all tasks.

**Good practices**:

- Ensure `ansible_user` has passwordless sudo configured
- Limit sudo to specific commands if possible:

  ```bash
  # /etc/sudoers.d/ansible
  ansible ALL=(ALL) NOPASSWD: /usr/bin/apt-get, /usr/bin/apt, /usr/bin/dnf, /usr/bin/zypper, /usr/sbin/reboot
  ```

- Use SSH key authentication (never passwords)
- Rotate Ansible user passwords periodically

---

### 6. **Limited Error Handling** (LOW RISK)

Some tasks use `ignore_errors: true` or `failed_when: false`:

```yaml
- name: "[Debian/Ubuntu] Update apt cache"
  ansible.builtin.apt:
    update_cache: true
  ignore_errors: true  # ⚠️  Masks real failures
```

**Why**: To continue with available packages when some repos fail

**Safe approach**:

- Warnings are displayed for failed operations
- Check the output for `⚠️  WARNING:` messages
- Investigate and fix problematic repositories before next run

---

## 📋 Safe Usage Checklist

### Pre-Execution

- [ ] Run playbook in `--check` mode first
- [ ] Review all proposed changes
- [ ] Test on staging/dev environment first
- [ ] Create system snapshots/backups
- [ ] Schedule during maintenance window
- [ ] Notify stakeholders of planned updates
- [ ] Review problematic repositories and remove if unnecessary

### Execution

- [ ] Use limited host selection (`-l groupname`)
- [ ] Use `--verbose` flag to see detailed output
- [ ] Monitor system metrics during execution
- [ ] Don't interrupt playbook mid-execution
- [ ] Check warning messages after completion

### Post-Execution

- [ ] Monitor system for issues (logs, services, resources)
- [ ] Verify all critical services started correctly
- [ ] Check for reboot messages in system logs
- [ ] Review update logs in `/var/log/ansible-updates/`
- [ ] Keep audit trail of all updates performed

---

## 🔐 Production Deployment Example

### For Production Systems

```bash
# Step 1: Dry run on staging
ansible-playbook -i inventory.yml playbooks/maintenance/update_packages.yml \
  -l staging \
  --check \
  -v

# Step 2: Review output carefully
# Look for warnings about repositories, package conflicts, etc.

# Step 3: Create snapshots (Proxmox)
pct snapshot 100 pre-update-2025-12-14

# Step 4: Run with approval gate
ansible-playbook -i inventory.yml playbooks/maintenance/update_packages.yml \
  -l production \
  -e "reboot_enabled=false" \
  -e "auto_approve_updates=false" \
  -v

# Step 5: Review completion summary
# Monitor system for 15-30 minutes

# Step 6: Schedule reboot separately during maintenance window
ansible-playbook -i inventory.yml playbooks/maintenance/update_packages.yml \
  -l production \
  -e "reboot_enabled=true" \
  --tags reboot \
  -v
```

---

## 🛡️ Repository Security

### Identify Problematic Repositories

The playbook will warn you about disabled repositories:

```text
⚠️  WARNING: Found disabled or problematic repositories on 192.168.0.125
Run 'zypper lr -d' to view them and consider removing problematic ones.
```

### Fix Issues

```bash
# On the target host, list all repositories:
sudo zypper lr

# Remove problematic ones:
sudo zypper rr warpdotdev  # Example: repository name

# Or disable them:
sudo zypper mr -d warpdotdev

# Verify repos are cleaned:
sudo zypper lr
```

---

## 📊 Monitoring & Logging

### Logs are saved in

```bash
/var/log/ansible-updates/update-YYYY-MM-DD-HH:MM:SS.log
```

### Monitor updates with

```bash
# Check recent updates
sudo tail -f /var/log/apt/history.log           # Debian/Ubuntu
sudo journalctl -u dnf -n 100                   # RHEL/CentOS
sudo zypper history                              # OpenSUSE

# Check if reboot is needed
cat /var/run/reboot-required               # Debian/Ubuntu
sudo needs-restarting -r                    # RHEL/CentOS
test -f /run/reboot-needed                  # OpenSUSE
```

---

## 🚨 Incident Response

### If Something Goes Wrong

1. **Stop the playbook**: Press `Ctrl+C`
2. **Check system status**:

   ```bash
   ssh <host>
   sudo systemctl status
   sudo journalctl -xe
   ```

3. **Rollback if needed** (if you have snapshots):

   ```bash
   pct rollback <CTID> pre-update-YYYYMMDD
   ```

4. **Report the issue**: Include full error message and logs

---

## 🔄 Maintenance Schedule

### Recommended Update Schedule

- **Development**: On-demand, no restrictions
- **Staging**: Weekly, Tuesday evenings, with approval
- **Production**:

  - Security updates: Weekly (automatic with approval)
  - Standard updates: Monthly (scheduled, manual approval)
  - Major updates: Quarterly (with extensive testing)

### Example Cron Jobs

```bash
# Weekly security updates check (Staging)
0 20 * * 2 /usr/bin/ansible-playbook -i /path/to/inventory.yml \
  /path/to/playbooks/maintenance/update_packages.yml \
  -l staging \
  --check >> /var/log/ansible-updates/weekly-check.log 2>&1

# Monthly full updates (requires manual approval)
0 2 1 * * /usr/bin/ansible-playbook -i /path/to/inventory.yml \
  /path/to/playbooks/maintenance/update_packages.yml \
  -l production \
  -e "reboot_enabled=false" \
  >> /var/log/ansible-updates/monthly-updates.log 2>&1
```

---

## 📚 References

- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [OWASP - Infrastructure Security](https://owasp.org/www-project-devsecops-guideline/)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/)
- [Red Hat - System Administration Security](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html-single/configuring_access_and_identity_infrastructure/index)

---

## ❓ Questions?

For security concerns or improvements, please:

1. Create an issue with security label
2. Contact the infrastructure team
3. Do NOT commit security credentials to repository

Last updated: December 2025
