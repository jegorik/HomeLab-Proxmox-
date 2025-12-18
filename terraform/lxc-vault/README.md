# HashiCorp Vault LXC Container - Terraform/OpenTofu

## 📋 Overview

This project automates the deployment of HashiCorp Vault in a Proxmox LXC container using Terraform/OpenTofu. It provides a complete Infrastructure as Code (IaC) solution for deploying a secrets management server in your homelab or development environment.

### Features

- ✅ Automated Vault installation and initialization
- ✅ Secure password generation with configurable complexity
- ✅ SSH key-based authentication
- ✅ State file encryption using AES-GCM
- ✅ S3 remote state backend with locking
- ✅ Unprivileged LXC container for enhanced security
- ✅ Systemd service integration
- ✅ Comprehensive documentation and best practices

### Architecture

```
┌─────────────────────────────────────────────┐
│         Proxmox VE Host                     │
│  ┌───────────────────────────────────────┐  │
│  │  LXC Container (Unprivileged)         │  │
│  │                                       │  │
│  │  ┌─────────────────────────────────┐  │  │
│  │  │  HashiCorp Vault                │  │  │
│  │  │  - Port: 8200                   │  │  │
│  │  │  - Storage: File Backend        │  │  │
│  │  │  - User: vault (system)         │  │  │
│  │  └─────────────────────────────────┘  │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

1. **Proxmox VE Server** (7.4+ or 8.x)
2. **OpenTofu** or **Terraform** (1.5+)
   ```bash
   # Install OpenTofu (recommended)
   curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh | bash
   ```
3. **SSH Key Pair** for container access
4. **Proxmox API Token** with appropriate permissions
5. **AWS Credentials** (for S3 backend state storage)
6. **LXC Template** downloaded on Proxmox:
   ```bash
   pveam download local debian-13-standard_13.1-2_amd64.tar.zst
   ```

### Step 1: Clone and Navigate

```bash
cd ~/your-homelab-repo/terraform/lxc-vault
```

### Step 2: Configure Variables

Create `terraform.tfvars` from the example:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
# Proxmox Configuration
proxmox_endpoint  = "https://192.168.1.100:8006"
proxmox_api_token = "terraform@pve!terraform-token=your-token-secret"
proxmox_node      = "pve"

# Container Configuration
lxc_id         = 105
lxc_hostname   = "vault"
lxc_ip_address = "192.168.1.50/24"  # or "dhcp"
lxc_gateway    = "192.168.1.1"

# Resources
lxc_cpu_cores = 2
lxc_memory    = 2048
lxc_disk_size = 10

# Storage
lxc_disk_storage     = "local-lvm"
lxc_template_storage = "local"
```

### Step 3: Configure State Encryption

Create a strong passphrase for state file encryption:

```bash
# Generate a secure passphrase
openssl rand -base64 32 > ~/.ssh/vault_state_passphrase
chmod 600 ~/.ssh/vault_state_passphrase
```

Update `terraform.tfvars`:

```hcl
passphrase = "~/.ssh/vault_state_passphrase"
```

### Step 4: Configure Ansible User (Optional)

If you want to enable automated management via Ansible:

```bash
# Generate separate SSH key for Ansible
ssh-keygen -t ed25519 -C "ansible@vault" -f ~/.ssh/ansible_vault
chmod 600 ~/.ssh/ansible_vault
chmod 644 ~/.ssh/ansible_vault.pub
```

Update `terraform.tfvars`:

```hcl
# Enable Ansible user
ansible_user_enabled         = true
ansible_user_name            = "ansible"
ansible_ssh_public_key_path  = "~/.ssh/ansible_vault.pub"
ansible_user_sudo            = true
ansible_user_sudo_commands   = []  # Empty = full sudo access
ansible_user_groups          = []  # Additional groups if needed
```

**Security Recommendations:**
- Use a separate SSH key for Ansible (not the same as root)
- For production, limit sudo commands instead of full access:
  ```hcl
  ansible_user_sudo_commands = [
    "/bin/systemctl restart vault",
    "/bin/systemctl status vault",
    "/bin/systemctl stop vault",
    "/bin/systemctl start vault",
    "/usr/bin/vault"
  ]
  ```

### Step 5: Configure S3 Backend

Edit `s3.backend.config`:

```hcl
bucket  = "your-terraform-state-bucket"
key     = "vault/vault.tfstate"
region  = "us-east-1"
profile = "your-aws-profile"
```

### Step 6: Initialize and Deploy

```bash
# Initialize Terraform with S3 backend
tofu init -backend-config=s3.backend.config

# Review the execution plan
tofu plan

# Apply the configuration
tofu apply
```

### Step 7: Secure Vault Keys

**⚠️ CRITICAL: This must be done immediately after deployment!**

```bash
# Retrieve initialization keys
scp root@192.168.1.50:/root/vault-keys.txt .

# Store keys in password manager (1Password, Bitwarden, etc.)
# You'll need:
# - 5 unseal keys (need 3 to unseal)
# - 1 root token

# Delete keys from container
ssh root@192.168.1.50 'shred -u /root/vault-keys.txt'

# Delete local copy after securing
shred -u vault-keys.txt
```

## 📖 Detailed Configuration

### Proxmox API Token Setup

1. **Access Proxmox Web UI**: `https://your-proxmox:8006`
2. **Navigate to**: Datacenter → Permissions → API Tokens
3. **Create Token**: 
   - User: `terraform@pve`
   - Token ID: `terraform-token`
   - Privilege Separation: ✅ Unchecked (for full permissions)
4. **Required Permissions** (on `/` path):
   ```
   Datastore.AllocateSpace
   Datastore.AllocateTemplate
   Datastore.Audit
   SDN.Use
   Sys.Audit
   Sys.Console
   VM.Allocate
   VM.Audit
   VM.Config.*
   VM.PowerMgmt
   ```

### AWS S3 Backend Setup

1. **Create S3 Bucket**:
   ```bash
   aws s3 mb s3://your-terraform-state-bucket --region us-east-1
   ```

2. **Enable Versioning**:
   ```bash
   aws s3api put-bucket-versioning \
     --bucket your-terraform-state-bucket \
     --versioning-configuration Status=Enabled
   ```

3. **Enable Encryption**:
   ```bash
   aws s3api put-bucket-encryption \
     --bucket your-terraform-state-bucket \
     --server-side-encryption-configuration '{
       "Rules": [{
         "ApplyServerSideEncryptionByDefault": {
           "SSEAlgorithm": "AES256"
         }
       }]
     }'
   ```

4. **Block Public Access**:
   ```bash
   aws s3api put-public-access-block \
     --bucket your-terraform-state-bucket \
     --public-access-block-configuration \
       "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
   ```

### SSH Key Configuration

If you don't have an SSH key pair:

```bash
# Generate new SSH key pair
ssh-keygen -t ed25519 -C "vault-container" -f ~/.ssh/id_ed25519

# Update terraform.tfvars
ssh_public_key_path = "~/.ssh/id_ed25519.pub"
```

## 🔒 Security Best Practices

### Container Security

✅ **Implemented:**
- Unprivileged LXC container (rootless)
- Dedicated system user for Vault
- Nesting enabled for systemd
- Protection against accidental deletion (optional)
- SSH key-based authentication only

❌ **Not Implemented (TODO):**
- TLS/SSL encryption (use reverse proxy)
- Firewall rules (iptables/nftables)
- AppArmor/SELinux profiles
- Network isolation (separate VLAN)

### Vault Security

✅ **Configured:**
- File-based storage backend
- Secure initialization key handling
- Memory lock capability (CAP_IPC_LOCK)
- Systemd hardening options

⚠️ **Production Recommendations:**
- Enable TLS (via reverse proxy like Nginx/Traefik)
- Use cloud storage backend (Consul, etcd, S3)
- Enable audit logging:
  ```bash
  vault audit enable file file_path=/var/log/vault/audit.log
  ```
- Configure auto-unseal (AWS KMS, Transit)
- Implement backup strategy for Vault data
- Set up monitoring and alerting
- Rotate root token after initial setup
- Use AppRole or OIDC instead of root token

### State File Security

✅ **Implemented:**
- AES-GCM encryption for local state
- PBKDF2 key derivation (600,000 iterations)
- S3 server-side encryption
- S3 bucket versioning
- State locking via S3

## 📊 Resource Specifications

### Default Allocations

| Resource | Default | Minimum | Recommended |
|----------|---------|---------|-------------|
| CPU Cores | 1 | 1 | 2 |
| Memory | 1024 MB | 512 MB | 2048 MB |
| Swap | 512 MB | 0 MB | 512 MB |
| Disk | 10 GB | 8 GB | 20 GB |

### Storage Requirements

- **Base OS**: ~500 MB
- **Vault Binary**: ~200 MB
- **Vault Data**: Grows with secrets (plan accordingly)
- **Logs**: ~100 MB/month (with audit logging)

## 🛠️ Post-Deployment Configuration

### 1. Unseal Vault

Vault starts sealed. You must unseal it after each restart:

```bash
export VAULT_ADDR='http://192.168.1.50:8200'

# Unseal using 3 of 5 keys
vault operator unseal <unseal-key-1>
vault operator unseal <unseal-key-2>
vault operator unseal <unseal-key-3>
```

### 2. Login and Initial Setup

```bash
# Login with root token
vault login <root-token>

# Enable KV secrets engine
vault secrets enable -version=2 kv

# Create first secret
vault kv put kv/my-secret value=s3cr3t

# Read secret
vault kv get kv/my-secret
```

### 3. Enable Audit Logging

```bash
# Create log directory
ssh root@192.168.1.50 'mkdir -p /var/log/vault && chown vault:vault /var/log/vault'

# Enable file audit
vault audit enable file file_path=/var/log/vault/audit.log

# Rotate logs with logrotate
ssh root@192.168.1.50 'cat > /etc/logrotate.d/vault <<EOF
/var/log/vault/*.log {
    daily
    rotate 30
    missingok
    notifempty
    compress
    delaycompress
    copytruncate
}
EOF'
```

### 4. Configure Authentication

```bash
# Enable username/password auth
vault auth enable userpass

# Create user
vault write auth/userpass/users/admin password=secure123

# Create policy
vault policy write admin -<<EOF
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF

# Attach policy to user
vault write auth/userpass/users/admin policies=admin

# Test login
vault login -method=userpass username=admin
```

### 5. Setup TLS (Recommended)

Use a reverse proxy (Nginx, Traefik, Caddy) for TLS:

**Nginx Example:**

```nginx
upstream vault {
    server 192.168.1.50:8200;
}

server {
    listen 443 ssl http2;
    server_name vault.yourdomain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://vault;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 🤖 Ansible Integration

### Enabling Ansible User

The project supports automatic creation of a dedicated Ansible user for automation:

```hcl
# In terraform.tfvars
ansible_user_enabled         = true
ansible_user_name            = "ansible"
ansible_ssh_public_key_path  = "~/.ssh/ansible_vault.pub"
ansible_user_sudo            = true
```

### Getting Ansible Inventory

After deployment, retrieve the Ansible inventory entry:

```bash
# Get formatted inventory entry
tofu output -raw ansible_inventory_entry

# Output example:
# vault:
#   ansible_host: 192.168.1.50
#   ansible_user: ansible
#   ansible_ssh_private_key_file: ~/.ssh/ansible_vault
#   ansible_python_interpreter: /usr/bin/python3
```

### Using with Ansible

1. **Add to your inventory.yml**:
   ```yaml
   all:
     children:
       vault_servers:
         hosts:
           vault:
             ansible_host: 192.168.1.50
             ansible_user: ansible
             ansible_ssh_private_key_file: ~/.ssh/ansible_vault
             ansible_python_interpreter: /usr/bin/python3
   ```

2. **Test connection**:
   ```bash
   ansible vault_servers -m ping
   ```

3. **Example playbook** (vault_manage.yml):
   ```yaml
   ---
   - name: Manage Vault Service
     hosts: vault_servers
     become: yes
     tasks:
       - name: Check Vault status
         systemd:
           name: vault
           state: started
         register: vault_status
       
       - name: Display Vault service status
         debug:
           var: vault_status
       
       - name: Restart Vault if needed
         systemd:
           name: vault
           state: restarted
         when: vault_restart_required | default(false)
   ```

4. **Run playbook**:
   ```bash
   ansible-playbook -i inventory.yml vault_manage.yml
   ```

### Security Best Practices for Ansible

- **Use separate SSH keys**: Don't reuse root's SSH key
- **Limit sudo commands**: Specify exact commands instead of NOPASSWD:ALL
- **Use Ansible Vault**: Encrypt sensitive variables
- **Rotate keys regularly**: Update SSH keys periodically
- **Audit access**: Enable logging for Ansible user actions

### Example: Limited Sudo Access

For production environments, restrict sudo commands:

```hcl
ansible_user_sudo_commands = [
  "/bin/systemctl restart vault",
  "/bin/systemctl status vault",
  "/bin/systemctl stop vault",
  "/bin/systemctl start vault",
  "/usr/bin/vault status",
  "/usr/bin/vault operator unseal"
]
```

### Retrieving Ansible SSH Command

```bash
# Get ready-to-use SSH command
tofu output ansible_ssh_command

# Output: ssh ansible@192.168.1.50
```

## 🔧 Maintenance

### Checking Vault Status

```bash
# From local machine
export VAULT_ADDR='http://192.168.1.50:8200'
vault status

# Inside container
ssh root@192.168.1.50
systemctl status vault
journalctl -u vault -f
```

### Backup Vault Data

```bash
# Backup data directory
ssh root@192.168.1.50 'tar czf /tmp/vault-backup-$(date +%Y%m%d).tar.gz /var/lib/vault/data'
scp root@192.168.1.50:/tmp/vault-backup-*.tar.gz ./backups/

# Backup using Vault snapshots (if using integrated storage)
vault operator raft snapshot save backup.snap
```

### Updating Vault

```bash
ssh root@192.168.1.50
apt update
apt upgrade vault
systemctl restart vault

# Unseal after restart
vault operator unseal
```

### Destroying Infrastructure

```bash
# ⚠️ WARNING: This will destroy the container and all data!
tofu destroy

# To keep backups, export data first
vault kv get -format=json secret/ > vault-secrets-backup.json
```

## 📚 Useful Commands

### Terraform/OpenTofu

```bash
# Format code
tofu fmt

# Validate configuration
tofu validate

# Show current state
tofu show

# List resources
tofu state list

# Get output values
tofu output
tofu output -raw lxc_root_password
tofu output -json > outputs.json
```

### Vault CLI

```bash
# Server status
vault status

# List secrets engines
vault secrets list

# List auth methods
vault auth list

# List policies
vault policy list

# Read policy
vault policy read default

# Token information
vault token lookup

# Seal Vault
vault operator seal
```

## 🐛 Troubleshooting

### Container won't start

```bash
# Check Proxmox logs
pct list
pct status <vmid>
pct start <vmid>

# Check journal logs
journalctl -xe
```

### Can't SSH to container

```bash
# Check IP address
pct exec <vmid> -- ip addr

# Test SSH key
ssh -vvv -i ~/.ssh/id_rsa root@192.168.1.50

# Reset root password (if needed)
pct enter <vmid>
passwd root
```

### Vault won't start

```bash
ssh root@192.168.1.50

# Check service status
systemctl status vault

# Check logs
journalctl -u vault -n 50

# Verify configuration
vault server -config=/etc/vault.d/vault.hcl -log-level=debug

# Check permissions
ls -la /var/lib/vault
ls -la /etc/vault.d
```

### State locking issues

```bash
# Force unlock (use with caution)
tofu force-unlock <lock-id>

# Check S3 bucket
aws s3 ls s3://your-bucket/vault/
```

### Vault is sealed

```bash
# Check seal status
vault status

# Unseal
vault operator unseal
```

## 📖 Additional Resources

### Official Documentation

- [Vault Documentation](https://developer.hashicorp.com/vault/docs)
- [Vault Tutorials](https://developer.hashicorp.com/vault/tutorials)
- [Proxmox VE Documentation](https://pve.proxmox.com/wiki/Main_Page)
- [OpenTofu Documentation](https://opentofu.org/docs/)
- [Terraform Proxmox Provider](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)

### Security Guides

- [Vault Production Hardening](https://developer.hashicorp.com/vault/tutorials/operations/production-hardening)
- [Vault Security Model](https://developer.hashicorp.com/vault/docs/internals/security)
- [LXC Security](https://linuxcontainers.org/lxc/security/)

### Vault Use Cases

- Store API keys and passwords
- Generate dynamic database credentials
- Manage SSH certificates
- PKI certificate management
- Encryption as a Service
- Kubernetes secrets management

## 🤝 Contributing

Improvements welcome! Please consider:

- Adding support for additional OS templates (Ubuntu, Alpine)
- Implementing automated backup scripts
- Adding Vault clustering support
- Creating Ansible playbooks for post-deployment config
- Improving error handling and validation

## 📝 License

This project is provided as-is for educational and homelab use.

## ⚠️ Disclaimer

This configuration is designed for development and homelab environments. For production use:

- Enable TLS encryption
- Use a proper storage backend (Consul, Integrated Storage)
- Implement auto-unseal
- Set up monitoring and alerting
- Follow the [official production hardening guide](https://developer.hashicorp.com/vault/tutorials/operations/production-hardening)
- Conduct security audits
- Implement proper backup and disaster recovery procedures

## 📧 Support

For issues and questions:
1. Check the troubleshooting section
2. Review Vault and Terraform documentation
3. Check Proxmox system logs
4. Open an issue with detailed error messages and logs

---

**Built with ❤️ for HomeLab enthusiasts**

*Last Updated: December 2025*

