# NetBox DCIM/IPAM - LXC Container Deployment

[![Terraform](https://img.shields.io/badge/Terraform-≥1.5-623CE4?logo=terraform)](https://www.terraform.io/)
[![Proxmox](https://img.shields.io/badge/Proxmox-VE_8.x-E57000?logo=proxmox)](https://www.proxmox.com/)
[![Vault](https://img.shields.io/badge/HashiCorp-Vault-000000?logo=vault)](https://www.vaultproject.io/)
[![NetBox](https://img.shields.io/badge/NetBox-v4.4.9-00C9FF)](https://netbox.dev/)

## 📋 Overview

Deploy NetBox DCIM/IPAM platform in a Debian 13 LXC container with automated infrastructure provisioning and secrets management. This Terraform module creates the container infrastructure and provisions an Ansible user, preparing the system for automated application deployment via the companion Ansible playbook.

**What this module does:**

- Creates unprivileged LXC container on Proxmox VE
- Provisions Ansible user with SSH key authentication and sudo access
- Stores all secrets in HashiCorp Vault (SSH keys, credentials)
- Encrypts Terraform state using Vault Transit engine
- Uses S3 remote backend with state locking
- Generates ready-to-use Ansible inventory entry

**What this module does NOT do:**

- Install NetBox application (handled by [Ansible playbook](../../scripts/ansible/playbooks/netbox-deploy/))
- Configure PostgreSQL, Redis, or web services (handled by Ansible)
- Create superuser account (handled by Ansible)

```text
┌───────────────────────────────────────────────────────────────┐
│                    Deployment Workflow                        │
├───────────────────────────────────────────────────────────────┤
│  [Vault] → [Terraform] → [LXC Container] → [Ansible] → NetBox │
│     ↓           ↓              ↓              ↓           ↓   │
│  Secrets   Infrastructure  Ansible User  Application  Web UI  │
└───────────────────────────────────────────────────────────────┘
```

## ✨ Features

### Infrastructure

- **Unprivileged LXC Container** - Enhanced security with user namespace isolation
- **Debian 13 Base OS** - Latest stable Debian with modern packages
- **Resource Configuration** - Customizable CPU, memory, disk, and network settings
- **Cloud-init Integration** - Automated initial configuration

### Security & Secrets Management

- **Vault Integration** - All secrets stored in HashiCorp Vault
- **State Encryption** - Terraform state encrypted with Vault Transit engine
- **SSH Key Management** - Keys retrieved from Vault, never stored in code
- **S3 Remote Backend** - Encrypted state storage with locking support
- **No Hardcoded Credentials** - All sensitive data sourced from Vault

### Automation & Integration

- **Ansible User Provisioning** - Automated user creation with SSH and sudo access
- **Inventory Generation** - Terraform output provides ready-to-paste inventory entry
- **Idempotent Deployment** - Safe to run multiple times
- **Credential Caching** - Optional encrypted local caching to avoid AWS credential duplication

## 🏗️ Architecture

```text
┌──────────────────────┐
│   HashiCorp Vault    │
│  (Secrets Storage)   │
└──────────┬───────────┘
           │ Retrieve credentials
           ↓
┌──────────────────────┐     ┌──────────────────────┐
│     Terraform        │────→│   Proxmox VE Host    │
│  (Infrastructure)    │     │                      │
└──────────────────────┘     │  ┌────────────────┐  │
           │                 │  │ LXC Container  │  │
           │ Provision       │  │  (Debian 13)   │  │
           ↓                 │  │                │  │
┌──────────────────────┐     │  │ - Ansible User │  │
│   Ansible Playbook   │────→│  │ - SSH Access   │  │
│  (NetBox Deploy)     │     │  │ - Sudo Rights  │  │
└──────────────────────┘     │  └────────────────┘  │
           │                 └──────────────────────┘
           ↓
     NetBox Running
   (PostgreSQL + Redis + Gunicorn + Nginx)
```

## 📦 Prerequisites

### Required Infrastructure

- **Proxmox VE 8.x** - Virtualization platform
- **HashiCorp Vault** - Secrets management server (accessible and unsealed)
- **OpenTofu/Terraform 1.5+** - Infrastructure provisioning tool
- **AWS S3 Bucket** - For remote state storage (with versioning enabled)
- **Age 1.2.0+** - Encryption tool for credential caching (optional)

### Proxmox Requirements

- Debian 13 LXC template downloaded and available
- Sufficient resources on target node (2GB RAM, 12GB disk minimum)
- Network connectivity and available IP address
- Storage for container disk

### Vault Setup Required

All secrets must be stored in Vault before running Terraform. Configure these KV v2 paths:

#### Proxmox API Credentials

```bash
# Proxmox API endpoint and authentication
vault kv put your-vault-path-for-proxmox-endpoint endpoint="https://pve.example.com:8006"
vault kv put your-vault-path-for-proxmox_node_name node_name="pve"
vault kv put your-vault-path-for-proxmox_user username="terraform@pve"

# Proxmox API token (recommended) or password
vault kv put your-vault-path-for-proxmox_api_token token_id="terraform@pve!mytoken" secret="your-secret-value"
```

#### SSH Keys

```bash
# Root SSH key (for initial provisioning)
vault kv put your-vault-path-for-root_ssh_public_key key="$(cat ~/.ssh/id_rsa.pub)"
vault kv put your-vault-path-for-root_ssh_private_key key="$(cat ~/.ssh/id_rsa)"

# Ansible SSH key (for application deployment)
vault kv put your-vault-path-for-ansible_ssh_public_key key="$(cat ~/.ssh/ansible.pub)"
```

#### S3 Backend

```bash
# S3 bucket for Terraform state
vault kv put your-vault-path-for-s3_bucket bucket_name="your-terraform-state-bucket"
```

#### AWS Credentials (Dynamic)

```bash
# Configure AWS secrets engine for dynamic credentials
vault secrets enable -path=aws/proxmox aws

vault write aws/proxmox/config/root \
    access_key="YOUR_AWS_ACCESS_KEY" \
    secret_key="YOUR_AWS_SECRET_KEY" \
    region="us-east-1"

vault write aws/proxmox/roles/tofu_state_backup \
    credential_type=iam_user \
    policy_document=-<<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowPBSBackupAccess",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:DeleteObject",
        "s3:GetObjectVersion",
        "s3:ListBucketVersions",
        "s3:PutObjectTagging"
      ],
      "Resource": [
        "arn:aws:s3:::your-terraform-state-bucket",
        "arn:aws:s3:::your-terraform-state-bucket/*"
      ]
    }
  ]
}
EOF
```

### Vault Transit Engine

```bash
# Enable Transit secrets engine for state encryption
vault secrets enable transit

# Create encryption key
vault write -f transit/keys/netbox-state-encryption
```

### Local Tools

```bash
# Install required tools
brew install opentofu age  # macOS
# or
sudo apt install age && wget https://github.com/opentofu/opentofu/releases/...  # Linux
```

## 🚀 Quick Start

### Step 1: Clone and Configure

```bash
# Navigate to project directory
cd terraform/lxc-netbox

# Copy configuration templates
cp terraform.tfvars.example terraform.tfvars
cp s3.backend.config.template s3.backend.config
cp vault_init.sh.example vault_init.sh

# Edit configuration files
nano terraform.tfvars
nano s3.backend.config
nano vault_init.sh
```

### Step 2: Configure Variables

Edit `terraform.tfvars` with your environment settings:

```hcl
# Vault Configuration
vault_address = "https://vault.example.com"
vault_username = "terraform_user"

# Proxmox Configuration
proxmox_endpoint_vault_path = "YOUR_VAULT_PATH_FOR_proxmox_endpoint"
proxmox_node_name_vault_path = "YOUR_VAULT_PATH_FOR_proxmox_node_name"

# Container Configuration
lxc_id = 100
lxc_hostname = "netbox"
lxc_ip_address = "192.168.1.205/24"
lxc_gateway = "192.168.1.1"
lxc_dns_servers = "192.168.1.1 1.1.1.1"

# Resource Allocation
lxc_cpu_cores = 2
lxc_memory = 2048  # MB
lxc_disk_size = 12  # GB

# Ansible User
ansible_user_enabled = true
ansible_user_name = "ansible"
ansible_user_sudo = true
```

See [terraform.tfvars.example](terraform.tfvars.example) for all available options.

### Step 3: Initialize Terraform

```bash
# Option A: Use vault_init.sh (recommended - handles authentication and caching)
source ./vault_init.sh

# Option B: Manual initialization
export VAULT_ADDR="https://vault.example.com"
export VAULT_TOKEN="$(vault login -token-only -method=userpass username=terraform_user)"
export TF_VAR_vault_password="your-vault-password"

# Generate AWS credentials
export AWS_ACCESS_KEY_ID="$(vault read -field=access_key YOUR_VAULT_PATH_FOR_AWS_CREDS)"
export AWS_SECRET_ACCESS_KEY="$(vault read -field=secret_key YOUR_VAULT_PATH_FOR_AWS_CREDS)"

# Initialize with S3 backend
tofu init -backend-config=s3.backend.config
```

### Step 4: Review and Deploy

```bash
# Validate configuration
tofu validate

# Review execution plan
tofu plan

# Deploy infrastructure
tofu apply

# Confirm with 'yes' when prompted
```

### Step 5: Retrieve Deployment Information

```bash
# View all outputs
tofu output

# Get Ansible inventory entry (copy this!)
tofu output ansible_inventory_entry

# Get SSH command
tofu output ssh_command

# Get root password (sensitive)
tofu output -raw lxc_root_password
```

**Example output:**

```yaml
# Add this to scripts/ansible/inventory.yml under the 'netbox' group:
    netbox:
      hosts:
        netbox:
          ansible_host: 192.168.1.205
          ansible_port: 22
          ansible_user: ansible
          ansible_python_interpreter: /usr/bin/python3
          ansible_ssh_private_key_file: ~/.ssh/ansible
      vars:
        ansible_become: true
        ansible_become_method: sudo
```

### Step 6: Deploy NetBox Application

```bash
# Navigate to Ansible directory
cd ../../scripts/ansible

# Edit inventory.yml and paste the entry from Terraform output
nano inventory.yml

# Deploy NetBox application
ansible-playbook -i inventory.yml playbooks/netbox-deploy/site.yml

# Access NetBox web interface
# URL: http://192.168.1.205

# Retrieve admin credentials from Vault
vault kv get secrets/proxmox/netbox
```

## 📁 Project Structure

```text
lxc-netbox/
├── README.md                      # This file
├── main.tf                        # LXC container + Ansible provisioner
├── variables.tf                   # Input variables with validation
├── outputs.tf                     # Outputs (inventory, SSH commands, etc.)
├── providers.tf                   # Vault + Proxmox providers
├── backend.tf                     # S3 backend configuration
├── encryption.tf                  # State encryption with Vault Transit
├── terraform.tfvars.example       # Example configuration (COPY THIS)
├── s3.backend.config.template     # S3 backend template (COPY THIS)
├── vault_init.sh.example          # Vault setup script (COPY THIS)
└── .gitignore                     # Excludes sensitive files
```

## 🔧 Configuration Reference

### Critical Variables

**Vault Authentication:**

```hcl
vault_address          = "https://vault.example.com"
vault_username         = "terraform_user"
vault_password         = "<set via TF_VAR_vault_password>"
vault_skip_tls_verify  = false  # Only true for homelab testing
```

**Container Identity:**

```hcl
lxc_id          = 100               # Unique VMID (100-999999999)
lxc_hostname    = "netbox"          # Container hostname
lxc_description = "NetBox DCIM/IPAM Platform"
```

**Network Configuration:**

```hcl
lxc_ip_address = "192.168.1.205/24"  # Static IP with CIDR
# OR
lxc_ip_address = "dhcp"              # Dynamic IP

lxc_gateway     = "192.168.1.1"      # Default gateway
lxc_dns_servers = "192.168.1.1 1.1.1.1"  # Space-separated DNS
```

**Resources:**

```hcl
lxc_cpu_cores = 2          # CPU cores
lxc_memory    = 2048       # RAM in MB
lxc_swap      = 512        # Swap in MB
lxc_disk_size = 12         # Disk size in GB
```

**Ansible User:**

```hcl
ansible_user_enabled = true
ansible_user_name    = "ansible"
ansible_user_sudo    = true
ansible_user_groups  = []  # Additional groups
```

See [variables.tf](variables.tf) for complete list with descriptions and validation rules.

### Vault Path Customization

All Vault paths are configurable:

```hcl
proxmox_api_token_vault_path  = "YOUR_VAULT_PATH_FOR_proxmox_api_token"
proxmox_endpoint_vault_path   = "YOUR_VAULT_PATH_FOR_proxmox_endpoint"
root_ssh_public_key_path      = "YOUR_VAULT_PATH_FOR_root_ssh_public_key"
ansible_ssh_public_key_path   = "YOUR_VAULT_PATH_FOR_ansible_ssh_public_key"
ephemeral_vault_mount_path    = "YOUR_VAULT_PATH_FOR_ephemeral_vault_mount"
```

## 📤 Outputs

### Container Information

- `lxc_id` - Proxmox container ID (VMID)
- `lxc_hostname` - Container hostname
- `lxc_ip_address` - IP address or "dhcp"
- `lxc_node` - Proxmox node name

### SSH Access

- `ssh_command` - Root SSH command: `ssh root@<ip>`
- `ansible_ssh_command` - Ansible user SSH: `ssh ansible@<ip>`
- `lxc_root_password` - Root password (sensitive, use `-raw`)

### Ansible Integration

- `ansible_inventory_entry` - Ready-to-paste YAML for inventory.yml
- `ansible_user_enabled` - Boolean flag
- `ansible_user_name` - Ansible username
- `next_steps` - Complete deployment instructions

### Resource Details

- `resource_summary` - CPU, memory, disk, storage info

**Retrieve sensitive outputs:**

```bash
tofu output -raw lxc_root_password
```

## 🔐 Security

### State Encryption

Terraform state files contain sensitive information and are encrypted using **Vault Transit engine**:

```hcl
# encryption.tf
resource "vault_transit_secret_backend_key" "state_encryption" {
  backend = "transit"
  name    = "netbox-state-encryption"
}
```

**Benefits:**

- Keys never leave Vault
- Automatic key versioning
- Centralized key management
- State encrypted at rest in S3

### Secrets Management

**Zero secrets in code:**

- ✅ SSH keys retrieved from Vault
- ✅ Proxmox credentials from Vault
- ✅ NetBox passwords generated and stored by Ansible in Vault
- ✅ State files encrypted
- ❌ No hardcoded passwords
- ❌ No credentials in version control

### Credential Caching

The `vault_init.sh` script includes optional credential caching:

```bash
# Cached credentials location
~/.terraform/lxc-netbox/credentials.enc

# Encrypted with age using key
~/.ssh/terraform-creds.key
```

**Benefits:**

- Prevents duplicate AWS credentials in Vault
- Speeds up repeated `terraform apply` operations
- Credentials cached for 5 minutes before TTL expiry
- Encrypted at rest with age

**Generate encryption key:**

```bash
age-keygen -o ~/.ssh/terraform-creds.key
```

### Best Practices

1. **Use unprivileged containers** (default in this module)
2. **Rotate Vault tokens regularly**
3. **Separate SSH keys** for root and Ansible users
4. **Enable Vault audit logging**
5. **Restrict Proxmox API token permissions**
6. **Enable S3 bucket versioning** for state rollback
7. **Use MFA for Vault authentication** (production)
8. **Review Terraform plans** before applying

### .gitignore Protection

Sensitive files automatically excluded:

```gitignore
terraform.tfvars
*.backend.conf
vault_init.sh
s3.backend.config
.terraform/
```

## 🔄 Workflow Integration

### Terraform → Ansible Integration

This project follows an **infrastructure-first, then application** deployment pattern:

```text
1. Terraform (this module)
   └─→ Creates LXC container
   └─→ Provisions Ansible user
   └─→ Outputs inventory entry
        │
        ↓ [Manual Step: Copy to inventory.yml]
        │
2. Ansible Playbook
   └─→ Installs PostgreSQL 17
   └─→ Installs Redis
   └─→ Deploys NetBox v4.4.9
   └─→ Configures systemd services
   └─→ Sets up Nginx reverse proxy
   └─→ Creates Django superuser
```

### Why Manual Inventory Update?

While Terraform could automatically update `inventory.yml`, we use a manual approach:

**Advantages:**

- ✅ Explicit control over inventory structure
- ✅ Group assignments require human decision
- ✅ Avoids Terraform managing Ansible files
- ✅ Clear separation of concerns
- ✅ Safer for version control

**Terraform makes it easy:**

```bash
# Copy to clipboard (macOS)
tofu output -raw ansible_inventory_entry | pbcopy

# Copy to clipboard (Linux)
tofu output -raw ansible_inventory_entry | xclip -selection clipboard

# View formatted
tofu output ansible_inventory_entry
```

### Post-Deployment

After Ansible completes:

```bash
# Access NetBox web interface
open http://192.168.1.205

# Retrieve admin credentials
vault kv get secrets/proxmox/netbox

# Example output:
# ====== Data ======
# Key                    Value
# ---                    -----
# db_password           randomgeneratedpassword123
# secret_key            django-secret-key-value
# superuser_email       admin@localhost
# superuser_password    adminpassword456
# superuser_username    admin
```

## 🛠️ Troubleshooting

### Terraform Issues

**Error: Cannot connect to Vault**

```bash
# Verify Vault is accessible
vault status

# Check Vault address
echo $VAULT_ADDR

# Test authentication
vault token lookup
```

**Error: Vault is sealed**

```bash
# Check seal status
vault status

# Unseal if needed
vault operator unseal
```

**Error: Permission denied on Vault path**

```bash
# Check your policy allows reading the path
vault policy read your-policy-name

# Test path access
vault kv get YOUR_VAULT_PATH_FOR_proxmox_endpoint
```

### Proxmox Issues

**Error: Container creation fails**

```bash
# Check node has resources
pvesh get /nodes/pve/status

# Verify template exists
pveam list local | grep debian-13

# Check storage space
pvesm status
```

**Error: IP address already in use**

```bash
# Find conflicting container
pvesh get /cluster/resources --type vm | grep "192.168.1.205"

# Choose different IP in terraform.tfvars
```

### Ansible User Issues

**SSH connection fails**

```bash
# Test root access first
ssh root@192.168.1.205

# Check Ansible user exists
ssh root@192.168.1.205 "id ansible"

# Verify SSH key
ssh root@192.168.1.205 "cat /home/ansible/.ssh/authorized_keys"

# Test Ansible user access
ssh -i ~/.ssh/ansible ansible@192.168.1.205
```

**Sudo not working**

```bash
# Check sudo group membership
ssh ansible@192.168.1.205 "groups"

# Verify sudoers file
ssh root@192.168.1.205 "cat /etc/sudoers.d/ansible"
```

### S3 Backend Issues

**Error: Access denied to S3 bucket**

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Test bucket access
aws s3 ls s3://your-terraform-state-bucket/

# Check bucket region matches backend config
aws s3api get-bucket-location --bucket your-terraform-state-bucket
```

### Credential Caching Issues

**Cached credentials invalid**

```bash
# Remove cache file
rm ~/.terraform/lxc-netbox/credentials.enc

# Re-run vault_init.sh
source ./vault_init.sh
```

**Age encryption fails**

```bash
# Verify age installed
age --version

# Check encryption key exists
ls -la ~/.ssh/terraform-creds.key

# Regenerate key if needed
age-keygen -o ~/.ssh/terraform-creds.key
```

### Debug Mode

Enable verbose logging:

```bash
# Terraform debug output
export TF_LOG=DEBUG
tofu apply

# Save logs to file
export TF_LOG_PATH="./terraform-debug.log"
tofu apply
```

## 🔗 Related Documentation

### Project Documentation

- [Ansible NetBox Playbook](../../scripts/ansible/playbooks/netbox-deploy/README.md) - Application deployment
- [Terraform Templates](../README.md) - Other infrastructure templates
- [Project Root](../../README.md) - Overall project structure
- [Ansible Automation Guide](../../scripts/ansible/AUTOMATION_GUIDE.md) - Ansible best practices
- [Security Guide](../../scripts/ansible/SECURITY_GUIDE.md) - Security considerations

### External Resources

- [NetBox Official Documentation](https://docs.netbox.dev/) - NetBox features and configuration
- [Proxmox LXC Documentation](https://pve.proxmox.com/wiki/Linux_Container) - LXC container management
- [HashiCorp Vault Documentation](https://developer.hashicorp.com/vault/docs) - Vault features
- [OpenTofu Documentation](https://opentofu.org/docs/) - Infrastructure as Code

## 🤝 Contributing

When modifying this infrastructure:

1. **Update terraform.tfvars.example** when adding new variables
2. **Document outputs** in this README when adding new output values
3. **Test changes** with `tofu plan` before committing
4. **Update version references** if changing NetBox version
5. **Keep Ansible playbook documentation in sync**
6. **Test full deployment workflow** (Terraform → Ansible → NetBox UI)

### Development Workflow

```bash
# Format code
tofu fmt -recursive

# Validate configuration
tofu validate

# Security scan (optional)
tfsec .

# Documentation generation (optional)
terraform-docs markdown . > README_AUTO.md
```

## 📝 Changelog

### v1.0.0 (January 2026)

- ✨ Initial NetBox LXC deployment module
- ✨ Debian 13 base operating system
- ✨ Vault integration for secrets management
- ✨ S3 remote state backend with locking
- ✨ Vault Transit encryption for state files
- ✨ Automated Ansible user provisioning
- ✨ Inventory entry auto-generation
- ✨ Credential caching with age encryption
- 📚 Comprehensive documentation

---

**Maintainer:** HomeLab Infrastructure Team  
**Last Updated:** January 5, 2026  
**Terraform Version:** >= 1.5.0  
**NetBox Version:** v4.4.9 (deployed via Ansible)  
**License:** MIT
