# Troubleshooting: Check Mode Issues

## Problem: Script Shows "Check mode: True" but Nothing Updates

### Root Cause

Your Semaphore Task Template has the `--check` flag enabled, which puts Ansible in **dry-run mode**. This previews changes but doesn't apply them.

### Solution: Fix Semaphore Task Configuration

1. **Open Semaphore UI**
2. **Go to Tasks → Templates**
3. **Find your "Update Packages" task**
4. **Click Edit**
5. **Look for the "Arguments" field**
6. **Remove `--check` if present**
7. **Save**

### Before (Wrong):

```text
Arguments: --check -i inventory.yml playbooks/maintenance/update_packages.yml
```

### After (Correct):

```text
Arguments: -i inventory.yml playbooks/maintenance/update_packages.yml
```

Or leave Arguments blank if the playbook path is set separately.

---

## Verify the Fix

Run the task again. You should see:

✅ **Correct (Real Updates)**:

```text
5:24:58 PM
Check mode: False
...
[TASK] [Debian/Ubuntu] Upgrade all packages
changed: [192.168.0.118]  ← Packages are actually updating
```

❌ **Wrong (Dry-Run Only)**:

```text
5:24:58 PM
Check mode: True
...
changed=3  ← But no actual changes were made
```

---

## Understand Check Mode vs Real Execution

| Mode | What Happens | Use Case |
|------|---|---|
| **Check Mode (`--check`)** | Preview changes, don't apply | Testing, auditing, safety check before real run |
| **Real Execution** | Actually apply changes | Production updates, scheduled automation |

---

## How to Run in Different Modes

### Via Semaphore UI (Recommended)

**For Testing (Check Mode)**:

1. In Task template, add `--check` to Arguments
2. Run the task
3. Review what WOULD change
4. If safe, remove `--check` and run again

**For Production (Real Updates)**:

1. Remove `--check` from Arguments
2. Save
3. Run the task
4. Packages will be actually updated

### Via Command Line

**Testing only**:

```bash
ansible-playbook -i inventory.yml playbooks/maintenance/update_packages.yml --check
```

**Real updates**:

```bash
ansible-playbook -i inventory.yml playbooks/maintenance/update_packages.yml
```

---

## Common Mistakes

### ❌ Mistake 1: Forgetting to Remove `--check`

```bash
# This will NOT update - just preview
ansible-playbook playbooks/maintenance/update_packages.yml --check
```

### ✅ Fix: Run without `--check`

```bash
# This WILL actually update packages
ansible-playbook playbooks/maintenance/update_packages.yml
```

---

### ❌ Mistake 2: Check flag in Semaphore Environment

```yaml
# In Semaphore environment variables - WRONG
ansible_check_mode: true
```

### ✅ Fix: Remove this variable

```yaml
# Don't set this for production runs
# Only set it when you want to test first
```

---

## Recommended Workflow

### Step 1: Create TWO Task Templates in Semaphore

**Template 1: "Update Packages - CHECK MODE" (Testing)**

```text
Arguments: --check -i inventory.yml playbooks/maintenance/update_packages.yml
Manual trigger only (not scheduled)
```

**Template 2: "Update Packages - APPLY" (Production)**

```text
Arguments: -i inventory.yml playbooks/maintenance/update_packages.yml
Scheduled: Tuesday 02:00 AM
```

### Step 2: Testing Workflow

1. Run "CHECK MODE" template
2. Review the output
3. If safe, proceed to step 3

### Step 3: Real Updates

1. Run "APPLY" template on schedule
2. Monitor logs
3. Done!

---

## Verify Your Current Setup

### Check What Semaphore is Running

In Semaphore UI:

1. Go to **Tasks → Templates**
2. Click your "Update Packages" task
3. Look at the **Playbook** field
4. Check if there are any **Arguments** with `--check`

### Expected Configuration

```text
Template Name: Update Packages
Playbook: scripts/ansible/playbooks/maintenance/update_packages.yml
Inventory: [your inventory name]
Repository: [your repo]
Arguments: [EMPTY or without --check]
Schedule: 0 2 * * 2  (Tuesday 2 AM)
```

---

## Monitor Real Updates

Once fixed, you should see:

```text
PLAY RECAP
192.168.0.118 : ok=13 changed=5  ← More changes mean packages were updated
192.168.0.117 : ok=13 changed=5  ← Numbers should be different each run
192.168.0.120 : ok=13 changed=3  ← Depends on available updates
```

And logs will be created:

```text
/var/log/ansible-updates/update-2025-12-14-17:30:00.log
```

---

## Still Not Working?

### Debug Steps

1. **Verify Semaphore task arguments**:

   ```bash
   # SSH to Semaphore host
   grep -r "update_packages" /opt/semaphore/config/
   ```

2. **Check task execution history**:
   - In Semaphore UI → Tasks → View past runs
   - Click on a run → View full output
   - Search for "Check mode" in the output

3. **Manually test the command**:

   ```bash
   cd /path/to/ansible
   ansible-playbook -i inventory.yml playbooks/maintenance/update_packages.yml
   ```

4. **Check Ansible version**:

   ```bash
   ansible --version
   ```

---

## Reference: Ansible Check Mode

- [Ansible Check Mode Documentation](https://docs.ansible.com/ansible/latest/user_guide/playbooks_checkmode.html)
- [Semaphore Task Configuration](https://docs.semaphoreui.com/)

---

**Summary**: Remove `--check` flag from your Semaphore task arguments, and the playbook will actually update packages instead of just previewing. 🚀
