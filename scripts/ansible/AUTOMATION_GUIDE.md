# Automation & Scheduling Guide

This guide shows how to use the `update_packages.yml` playbook in real-world automation scenarios.

## Overview: Two Patterns

### Pattern 1: Pure Automation (Recommended for Homelab/Semaphore)

- ✅ Runs automatically on schedule
- ✅ No manual approval needed
- ✅ Logs everything
- ✅ Ideal for non-critical infrastructure

### Pattern 2: Scheduled with Safety Windows

- ✅ Runs automatically during maintenance window
- ✅ Time-controlled reboots
- ✅ Better for production
- ✅ Requires initial setup

---

## Pattern 1: Pure Automation via Semaphore

### Setup (One-time)

1. **Create a Semaphore Task Template**:
   - Template Name: `Update Packages - Daily`
   - Playbook: `scripts/ansible/playbooks/maintenance/update_packages.yml`
   - Inventory: Your production inventory
   - Environment: Leave default

2. **Configure Environment Variables**:

   ```yaml
   reboot_enabled: false
   only_security_updates: false
   enable_update_logging: true
   ```

3. **Set Schedule**:
   - Frequency: Daily at 02:00 AM
   - Days: Tuesday, Thursday, Saturday

### Usage

The playbook runs **automatically every scheduled day**. That's it!

```bash
# Monitor logs in Semaphore UI
# Or SSH to any host and check:
tail -f /var/log/ansible-updates/*.log
```

### Real-World Example: Simple Homelab Schedule

```text
Monday:    Nothing (maintenance window prep)
Tuesday:   02:00 AM - Update all staging
Wednesday: Monitor for issues
Thursday:  02:00 AM - Update all production
Friday:    Monitor
Saturday:  02:00 AM - Full update including reboots (-e "reboot_enabled=true")
Sunday:    Monitor and report
```

---

## Pattern 2: Automated with Scheduled Reboots

For systems that need controlled reboot timing:

### Daily Updates (No Reboot)

```bash
# Via Cron on Semaphore host:
0 2 * * * ansible-playbook \
  -i /path/to/inventory.yml \
  /path/to/update_packages.yml \
  -e "reboot_enabled=false"
```

### Weekly Reboots (Separate Task)

```bash
# Via Cron - Sunday 3:00 AM (2 hours after updates)
0 3 * * 0 ansible-playbook \
  -i /path/to/inventory.yml \
  /path/to/update_packages.yml \
  -e "reboot_enabled=true" \
  --tags reboot \
  -l production
```

### Benefits of This Pattern

- Updates happen frequently (daily)
- Reboots are controlled (once per week)
- Systems stay current with security patches
- Services have predictable restart time

---

## Pattern 3: Production with Environment Separation

For enterprise-like setups with dev/staging/prod:

### Development Environment

```bash
# Update immediately, reboot immediately
ansible-playbook -i inventory/dev.yml playbooks/maintenance/update_packages.yml \
  -e "reboot_enabled=true"
```

### Staging Environment (Testing)

```bash
# Dry run first (always)
ansible-playbook -i inventory/staging.yml playbooks/maintenance/update_packages.yml --check

# Then update, no reboot (for testing)
ansible-playbook -i inventory/staging.yml playbooks/maintenance/update_packages.yml \
  -e "reboot_enabled=false"
```

### Production Environment

```bash
# Tuesday 1:00 AM - Update only
0 1 * * 2 ansible-playbook \
  -i inventory/production.yml \
  playbooks/maintenance/update_packages.yml \
  -e "reboot_enabled=false"

# Tuesday 3:00 AM - Controlled reboot (in shifts)
0 3 * * 2 ansible-playbook \
  -i inventory/production.yml \
  playbooks/maintenance/update_packages.yml \
  -e "reboot_enabled=true" \
  --tags reboot \
  -l "prod_group_1"

0 4 * * 2 ansible-playbook \
  -i inventory/production.yml \
  playbooks/maintenance/update_packages.yml \
  -e "reboot_enabled=true" \
  --tags reboot \
  -l "prod_group_2"
```

**Why this approach?**

- Group reboots prevent service loss
- 1-hour gap between updates and reboots allows monitoring
- Rolling restart pattern maintains service availability

---

## Real Enterprise Example: Netflix-style Pattern

This is how many cloud-native companies do it:

### Architecture

```text
┌─────────────────────────────────────────┐
│     Vulnerability Scanner (Daily)       │
│  - Identifies security patches          │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│   Patch Staging Environment             │
│  - Applies updates automatically        │
│  - Runs integration tests               │
│  - No reboots for testing               │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│   Production Blue-Green Deployment      │
│  - Update blue environment (odd servers)│
│  - Traffic stays on green (even servers)│
│  - Reboot blue servers                  │
│  - Failover to blue                     │
│  - Repeat for green                     │
└─────────────────────────────────────────┘
```

### Implementation with Ansible

```bash
#!/bin/bash
# daily-patch.sh - Run by cron or CI/CD

INVENTORY="/etc/ansible/inventory"

# Phase 1: Update staging (1:00 AM)
ansible-playbook -i $INVENTORY playbooks/maintenance/update_packages.yml \
  -l staging \
  -e "reboot_enabled=true"

# Phase 2: Wait for health checks (2:00 AM)
sleep 3600
./health-check.sh staging || exit 1

# Phase 3: Update odd-numbered prod servers (3:00 AM - blue)
ansible-playbook -i $INVENTORY playbooks/maintenance/update_packages.yml \
  -l "prod_odd" \
  -e "reboot_enabled=true"

# Phase 4: Verify and failover
./failover.sh blue || rollback.sh blue
sleep 1800

# Phase 5: Update even-numbered prod servers (4:30 AM - green)
ansible-playbook -i $INVENTORY playbooks/maintenance/update_packages.yml \
  -l "prod_even" \
  -e "reboot_enabled=true"

# Phase 6: Final verification
./health-check.sh production || exit 1
echo "Patching complete" | mail -s "Daily Patch Complete" ops@company.com
```

---

## Semaphore Integration Examples

### Simple Daily Update Task

```yaml
# Semaphore Task Template
name: Daily Package Updates
type: task
playbook: scripts/ansible/playbooks/maintenance/update_packages.yml
inventory: production
schedule: "0 2 * * *"  # Daily at 2 AM
variables:
  reboot_enabled: false
  only_security_updates: false
  enable_update_logging: true
```

### Advanced: On-Demand with Parameters

```yaml
# Semaphore Task Template (Interactive)
name: On-Demand Package Update
type: task
playbook: scripts/ansible/playbooks/maintenance/update_packages.yml
inventory: production
options:
  - name: "target_environment"
    default: "staging"
    type: select
    values: ["staging", "production"]
  - name: "enable_reboot"
    default: "false"
    type: boolean
  - name: "security_only"
    default: "false"
    type: boolean
variables_override:
  reboot_enabled: "{{ enable_reboot }}"
  only_security_updates: "{{ security_only }}"
```

---

## Monitoring & Alerting

### Check Update Logs

```bash
# On target host
sudo tail -100 /var/log/ansible-updates/update-*.log

# Or from control host
ansible -i inventory.yml all -m shell -a "tail /var/log/ansible-updates/update-*.log"
```

### Set Up Alerts

**Elasticsearch + Kibana**:

```json
{
  "alert": "PackageUpdateFailed",
  "condition": "ansible-updates.status == 'FAILED'",
  "action": "notify_ops_channel"
}
```

**Simple Email Alert**:

```bash
#!/bin/bash
# In your Semaphore post-task hook
if [ $? -ne 0 ]; then
  echo "Package update failed on multiple hosts" | \
    mail -s "ALERT: Patch Failure" ops@company.com
fi
```

---

## Comparison: Real-World Strategies

| Strategy | Frequency | Reboot | Approval | Best For |
|----------|-----------|--------|----------|----------|
| **Daily Auto** | Every day | Scheduled weekly | None | Homelab, Non-critical |
| **Weekly Windows** | Every Tuesday | Tuesday 3 AM | None | Typical production |
| **Monthly Planned** | First Tuesday | After testing | None | Conservative ops |
| **Blue-Green** | Continuous | Rolling | None | Cloud-native, zero-downtime |
| **Manual Approval** | On-demand | Never | Always | Critical production |

---

## Security vs. Availability Trade-offs

```text
High Security (Fast Patches)
        ↑
        │  Daily auto-updates
        │  ├─ Pro: Latest security fixes
        │  ├─ Con: More reboots
        │
        │  Weekly scheduled
        │  ├─ Pro: Balanced approach
        │  ├─ Con: 7-day delay possible
        │
        │  Monthly updates
        │  ├─ Pro: Stable, predictable
        │  ├─ Con: Slow security response
        │
        └─────────────────────────────→
         Low Availability Risk (Longer intervals)

RECOMMENDED: Weekly for most organizations
```

---

## Troubleshooting Automated Runs

### Problem: Playbook Hangs

**Cause**: Usually reboot timeout or SSH issues

```bash
# Add timeout to cron
timeout 1800 ansible-playbook ... # 30 minute timeout

# Or increase in playbook
timeout: 600  # in playbook defaults
```

### Problem: Updates Not Running

**Debug**:

```bash
# Check Semaphore logs
grep "update_packages" /var/log/semaphore/semaphore.log

# Check cron
crontab -l | grep ansible

# Check if job is stuck
ps aux | grep ansible
```

### Problem: Repositories Failing

This is expected - the playbook handles it:

```bash
# Check which repos failed
grep "WARNING" /var/log/ansible-updates/update-*.log

# Fix problematic repo
ssh <host>
sudo zypper rr <repo-name>
# or
sudo apt-key adv --keyserver ... --recv-keys ...
```

---

## Final Recommendation for Your Homelab

**Use this approach:**

1. **Keep `auto_approve_updates: true`** (default now)
2. **Set up Semaphore schedule**:
   - Tuesday 02:00 AM - Update without reboot
   - Saturday 02:00 AM - Update with reboot
3. **Monitor the logs** via Semaphore or `/var/log/ansible-updates/`
4. **Email notifications** if something fails
5. **Done!** Completely automated, secure, and healthy

This is how real DevOps teams do it. The playbook is now **properly automated**.

---

References:

- [CIS Patch Management Maturity](https://www.cisecurity.org/cis-benchmarks/)
- [Red Hat Patch Management](https://www.redhat.com/en/engage/patch-management-2023)
- [Netflix Tech Blog - Automation](https://netflixtechblog.com/)
