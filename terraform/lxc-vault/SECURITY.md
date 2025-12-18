# Security Guide - HashiCorp Vault LXC Container

## 🔒 Security Overview

This document outlines security considerations, best practices, and hardening steps for the Vault LXC container deployment.

## Table of Contents

1. [Infrastructure Security](#infrastructure-security)
2. [Vault Security](#vault-security)
3. [Network Security](#network-security)
4. [State File Security](#state-file-security)
5. [Secrets Management](#secrets-management)
6. [Compliance](#compliance)

---

## Infrastructure Security

### LXC Container Hardening

#### ✅ Implemented

- **Unprivileged Container**: Runs in rootless mode by default
- **Dedicated System User**: Vault runs as `vault` user, not root
- **SSH Key Authentication**: Password-based SSH disabled
- **Nesting Enabled**: Required for systemd, minimal privilege escalation
- **Resource Limits**: CPU, memory, and disk quotas enforced

#### 🔧 Additional Hardening Steps

1. **Enable AppArmor Profile**
   ```bash
   # On Proxmox host
   pct set <vmid> -features nesting=1,apparmor=1
   
   # Inside container, install AppArmor
   apt install apparmor apparmor-utils
   
   # Create Vault AppArmor profile
   cat > /etc/apparmor.d/usr.bin.vault <<'EOF'
   #include <tunables/global>
   
   /usr/bin/vault {
     #include <abstractions/base>
     #include <abstractions/nameservice>
     
     capability ipc_lock,
     capability sys_resource,
     
     /usr/bin/vault mr,
     /etc/vault.d/ r,
     /etc/vault.d/** r,
     /var/lib/vault/ rw,
     /var/lib/vault/** rw,
     /proc/sys/kernel/random/uuid r,
     
     # Network
     network inet stream,
     network inet6 stream,
   }
   EOF
   
   # Enable profile
   apparmor_parser -r /etc/apparmor.d/usr.bin.vault
   ```

2. **Implement Firewall Rules**
   ```bash
   # Install nftables
   apt install nftables
   
   # Create firewall rules
   cat > /etc/nftables.conf <<'EOF'
   #!/usr/sbin/nft -f
   
   flush ruleset
   
   table inet filter {
     chain input {
       type filter hook input priority 0; policy drop;
       
       # Allow loopback
       iif lo accept
       
       # Allow established connections
       ct state established,related accept
       
       # Allow SSH (port 22)
       tcp dport 22 accept
       
       # Allow Vault (port 8200) from specific subnet
       ip saddr 192.168.0.0/16 tcp dport 8200 accept
       
       # Drop everything else
       drop
     }
     
     chain forward {
       type filter hook forward priority 0; policy drop;
     }
     
     chain output {
       type filter hook output priority 0; policy accept;
     }
   }
   EOF
   
   # Enable and start
   systemctl enable nftables
   systemctl start nftables
   ```

3. **Disable Unnecessary Services**
   ```bash
   # List running services
   systemctl list-units --type=service --state=running
   
   # Disable unnecessary services
   systemctl disable --now bluetooth
   systemctl disable --now cups
   ```

4. **Enable Automatic Security Updates**
   ```bash
   apt install unattended-upgrades
   dpkg-reconfigure -plow unattended-upgrades
   
   # Configure
   cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
   Unattended-Upgrade::Allowed-Origins {
       "${distro_id}:${distro_codename}-security";
   };
   Unattended-Upgrade::AutoFixInterruptedDpkg "true";
   Unattended-Upgrade::Remove-Unused-Dependencies "true";
   Unattended-Upgrade::Automatic-Reboot "false";
   EOF
   ```

### Proxmox Host Security

1. **API Token Permissions**: Use minimal required permissions
2. **Separate Tokens**: Use different tokens for different projects
3. **Token Expiration**: Implement token rotation policy
4. **Network Isolation**: Place Vault on dedicated VLAN if possible

### Ansible User Security

If you enable the Ansible automation user, follow these security practices:

#### ✅ Best Practices

1. **Use Separate SSH Keys**
   ```bash
   # Generate dedicated key for Ansible
   ssh-keygen -t ed25519 -C "ansible@vault-automation" -f ~/.ssh/ansible_vault
   chmod 600 ~/.ssh/ansible_vault
   ```

2. **Limit Sudo Commands**
   ```hcl
   # Instead of full sudo access
   ansible_user_sudo_commands = [
     "/bin/systemctl restart vault",
     "/bin/systemctl status vault",
     "/bin/systemctl stop vault",
     "/bin/systemctl start vault",
     "/usr/bin/vault status"
   ]
   ```

3. **Enable Sudo Logging**
   ```bash
   # On container
   cat >> /etc/sudoers.d/ansible <<'EOF'
   Defaults:ansible log_output
   Defaults:ansible!/usr/bin/sudoreplay !log_output
   EOF
   ```

4. **Restrict SSH Access**
   ```bash
   # In /home/ansible/.ssh/authorized_keys, prepend:
   from="192.168.1.0/24",no-port-forwarding,no-X11-forwarding,no-agent-forwarding ssh-ed25519 AAAA...
   ```

5. **Key Rotation Schedule**
   - Rotate Ansible SSH keys every 90 days
   - Document key rotation in maintenance calendar
   - Use Ansible Vault for storing credentials

6. **Audit Ansible Actions**
   ```bash
   # Enable auditd for Ansible user
   apt install auditd
   auditctl -w /etc/vault.d -p wa -k vault_config_change
   auditctl -w /var/lib/vault -p wa -k vault_data_change
   
   # Monitor logs
   ausearch -k vault_config_change
   ```

#### 🔒 Additional Hardening

1. **Two-Factor Authentication** (Advanced)
   ```bash
   # Install Google Authenticator
   apt install libpam-google-authenticator
   
   # Configure for Ansible user
   su - ansible
   google-authenticator
   
   # Update /etc/pam.d/sshd
   echo "auth required pam_google_authenticator.so" >> /etc/pam.d/sshd
   ```

2. **SSH Certificate Authority** (Advanced)
   ```bash
   # Use SSH certificates instead of keys
   # This allows time-limited access and easier revocation
   ```

3. **Disable Password Authentication**
   ```bash
   # In /etc/ssh/sshd_config
   PasswordAuthentication no
   ChallengeResponseAuthentication no
   ```

---

## Vault Security

### Initial Setup Security

#### ✅ Critical: Secure Initialization Keys

```bash
# After deployment, IMMEDIATELY:
# 1. Retrieve keys
scp root@<vault-ip>:/root/vault-keys.txt .

# 2. Store in password manager (1Password, Bitwarden, Keeper, etc.)
#    - 5 Unseal Keys
#    - 1 Root Token

# 3. Delete from server
ssh root@<vault-ip> 'shred -u /root/vault-keys.txt'

# 4. Delete local copy after securing
shred -u vault-keys.txt
```

### Production Hardening

1. **Enable TLS/SSL**
   
   **Option A: Reverse Proxy (Recommended)**
   ```nginx
   # Nginx with Let's Encrypt
   server {
       listen 443 ssl http2;
       server_name vault.yourdomain.com;
       
       ssl_certificate /etc/letsencrypt/live/vault.yourdomain.com/fullchain.pem;
       ssl_certificate_key /etc/letsencrypt/live/vault.yourdomain.com/privkey.pem;
       ssl_protocols TLSv1.2 TLSv1.3;
       ssl_ciphers HIGH:!aNULL:!MD5;
       ssl_prefer_server_ciphers on;
       
       location / {
           proxy_pass http://192.168.1.50:8200;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto https;
       }
   }
   ```

   **Option B: Vault Native TLS**
   ```bash
   # Generate certificate
   openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
     -keyout /etc/vault.d/vault-key.pem \
     -out /etc/vault.d/vault-cert.pem
   
   # Update vault.hcl
   listener "tcp" {
     address     = "0.0.0.0:8200"
     tls_cert_file = "/etc/vault.d/vault-cert.pem"
     tls_key_file  = "/etc/vault.d/vault-key.pem"
     tls_min_version = "tls12"
   }
   ```

2. **Enable Audit Logging**
   ```bash
   # Create audit log directory
   mkdir -p /var/log/vault
   chown vault:vault /var/log/vault
   chmod 750 /var/log/vault
   
   # Enable audit device
   vault audit enable file file_path=/var/log/vault/audit.log
   
   # Configure log rotation
   cat > /etc/logrotate.d/vault <<'EOF'
   /var/log/vault/*.log {
       daily
       rotate 30
       compress
       delaycompress
       missingok
       notifempty
       create 0640 vault vault
       sharedscripts
       postrotate
           killall -HUP vault 2>/dev/null || true
       endscript
   }
   EOF
   ```

3. **Implement Auto-Unseal**
   
   **AWS KMS Auto-Unseal Example:**
   ```hcl
   seal "awskms" {
     region     = "us-east-1"
     kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/abcd1234-..."
   }
   ```

4. **Rotate Root Token**
   ```bash
   # Generate new root token
   vault operator generate-root -init
   vault operator generate-root -nonce=<nonce> <unseal-key-1>
   vault operator generate-root -nonce=<nonce> <unseal-key-2>
   vault operator generate-root -nonce=<nonce> <unseal-key-3>
   
   # Revoke old root token
   vault token revoke <old-root-token>
   ```

5. **Enable MFA**
   ```bash
   # Enable TOTP MFA
   vault write sys/mfa/method/totp/my_totp \
     issuer=Vault \
     period=30 \
     key_size=20 \
     algorithm=SHA256 \
     digits=6
   ```

### Access Control

1. **Create Policies (Least Privilege)**
   ```bash
   # Read-only policy
   vault policy write readonly - <<EOF
   path "secret/data/*" {
     capabilities = ["read", "list"]
   }
   EOF
   
   # Admin policy
   vault policy write admin - <<EOF
   path "*" {
     capabilities = ["create", "read", "update", "delete", "list", "sudo"]
   }
   EOF
   
   # Developer policy
   vault policy write developer - <<EOF
   path "secret/data/dev/*" {
     capabilities = ["create", "read", "update", "delete", "list"]
   }
   path "secret/metadata/dev/*" {
     capabilities = ["list"]
   }
   EOF
   ```

2. **Use AppRole Instead of Root Token**
   ```bash
   # Enable AppRole
   vault auth enable approle
   
   # Create role
   vault write auth/approle/role/my-app \
     secret_id_ttl=24h \
     token_ttl=20m \
     token_max_ttl=30m \
     policies="developer"
   
   # Get RoleID and SecretID
   vault read auth/approle/role/my-app/role-id
   vault write -f auth/approle/role/my-app/secret-id
   ```

3. **Enable LDAP/OIDC Authentication**
   ```bash
   # LDAP example
   vault auth enable ldap
   vault write auth/ldap/config \
     url="ldap://ldap.example.com" \
     userdn="ou=users,dc=example,dc=com" \
     groupdn="ou=groups,dc=example,dc=com" \
     binddn="cn=vault,ou=users,dc=example,dc=com" \
     bindpass="password"
   ```

---

## Network Security

### Network Segmentation

1. **Dedicated VLAN for Vault**
   ```
   VLAN 100: Management (Proxmox, SSH)
   VLAN 200: Applications
   VLAN 300: Vault and Security Services
   ```

2. **Firewall Rules**
   ```
   # Allow only necessary traffic
   Source: Application Servers (VLAN 200)
   Destination: Vault (VLAN 300)
   Port: 8200
   Protocol: TCP
   
   # Management access
   Source: Admin Network (VLAN 100)
   Destination: Vault (VLAN 300)
   Ports: 22, 8200
   Protocol: TCP
   ```

### Rate Limiting

```bash
# In vault.hcl
listener "tcp" {
  address = "0.0.0.0:8200"
  
  # Rate limiting
  rate_limit {
    limit_interval = "1m"
    limit_per_interval = 100
  }
}
```

---

## State File Security

### OpenTofu State Encryption

✅ **Implemented**: AES-GCM with PBKDF2 key derivation

**Passphrase Management Best Practices:**

1. **Generate Strong Passphrase**
   ```bash
   # 32-byte random passphrase
   openssl rand -base64 32 > ~/.ssh/vault_state_passphrase
   chmod 600 ~/.ssh/vault_state_passphrase
   ```

2. **Store in Secrets Manager**
   - AWS Secrets Manager
   - Azure Key Vault
   - HashiCorp Vault (for other projects)
   - 1Password/Bitwarden

3. **Rotate Periodically**
   ```bash
   # Generate new passphrase
   openssl rand -base64 32 > ~/.ssh/vault_state_passphrase_new
   
   # Update terraform.tfvars
   # Re-encrypt state
   tofu init -reconfigure -backend-config=s3.backend.config
   ```

### S3 Backend Security

✅ **Implemented**:
- S3 server-side encryption
- Bucket versioning
- State locking

**Additional Hardening:**

1. **Enable MFA Delete**
   ```bash
   aws s3api put-bucket-versioning \
     --bucket your-bucket \
     --versioning-configuration Status=Enabled,MFADelete=Enabled \
     --mfa "arn:aws:iam::123456789012:mfa/user 123456"
   ```

2. **Bucket Policy**
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "AWS": "arn:aws:iam::123456789012:user/terraform"
         },
         "Action": [
           "s3:GetObject",
           "s3:PutObject",
           "s3:DeleteObject"
         ],
         "Resource": "arn:aws:s3:::your-bucket/vault/*"
       }
     ]
   }
   ```

3. **Enable CloudTrail**
   ```bash
   aws cloudtrail create-trail \
     --name terraform-state-audit \
     --s3-bucket-name your-audit-bucket
   ```

---

## Secrets Management

### Vault Secrets Best Practices

1. **Secret Rotation**
   ```bash
   # Enable database secrets engine
   vault secrets enable database
   
   # Configure with automatic rotation
   vault write database/config/mysql \
     plugin_name=mysql-database-plugin \
     connection_url="{{username}}:{{password}}@tcp(mysql:3306)/" \
     allowed_roles="*" \
     username="root" \
     password="rootpass" \
     password_rotation_period="24h"
   ```

2. **Transit Encryption**
   ```bash
   # Enable transit engine for encryption-as-a-service
   vault secrets enable transit
   vault write -f transit/keys/my-key
   
   # Encrypt data
   vault write transit/encrypt/my-key plaintext=$(base64 <<< "sensitive data")
   ```

3. **PKI Management**
   ```bash
   # Enable PKI
   vault secrets enable pki
   vault secrets tune -max-lease-ttl=87600h pki
   
   # Generate root CA
   vault write pki/root/generate/internal \
     common_name="My Root CA" \
     ttl=87600h
   ```

---

## Compliance

### Audit Requirements

1. **Log All Access**
   - Enable audit logging (file and syslog)
   - Forward logs to SIEM
   - Retain logs for compliance period

2. **Regular Security Audits**
   ```bash
   # Check Vault policies
   vault policy list
   vault policy read <policy-name>
   
   # Review auth methods
   vault auth list -detailed
   
   # Check secrets engines
   vault secrets list -detailed
   
   # Review active tokens
   vault list auth/token/accessors
   ```

3. **Vulnerability Scanning**
   ```bash
   # Inside container
   apt install lynis
   lynis audit system
   
   # Check for CVEs
   apt update
   apt list --upgradable
   ```

### Compliance Standards

- **GDPR**: Encrypt personal data, implement data retention
- **PCI-DSS**: Strong access controls, audit logging, encryption
- **HIPAA**: Access controls, audit trails, encryption at rest and in transit
- **SOC 2**: Monitoring, logging, access controls, incident response

---

## Security Checklist

### Deployment Phase

- [ ] Strong passphrase for state encryption (32+ characters)
- [ ] Secure Proxmox API token with minimal permissions
- [ ] SSH keys instead of passwords
- [ ] S3 bucket with encryption and versioning
- [ ] Unprivileged LXC container

### Initial Configuration

- [ ] Retrieve and secure Vault initialization keys
- [ ] Delete initialization keys from container
- [ ] Unseal Vault
- [ ] Enable audit logging
- [ ] Rotate root token
- [ ] Create administrative policies
- [ ] Enable authentication method (LDAP/OIDC)

### Ongoing Operations

- [ ] Enable TLS/SSL (reverse proxy or native)
- [ ] Configure auto-unseal
- [ ] Implement backup strategy
- [ ] Set up monitoring and alerting
- [ ] Regular security audits
- [ ] Keep Vault and OS updated
- [ ] Review and rotate secrets regularly
- [ ] Test disaster recovery procedures

---

## Incident Response

### Compromised Root Token

1. **Generate new root token**
2. **Revoke old token**
3. **Audit access logs**
4. **Rotate all secrets**
5. **Review and update policies**

### Container Breach

1. **Isolate container (stop networking)**
2. **Create snapshot for forensics**
3. **Review Vault audit logs**
4. **Rotate all secrets**
5. **Rebuild container from clean state**
6. **Update security controls**

### Data Exfiltration

1. **Review audit logs**
2. **Identify compromised secrets**
3. **Revoke access tokens**
4. **Rotate compromised secrets**
5. **Notify affected parties**
6. **Implement additional controls**

---

## Additional Resources

- [Vault Security Model](https://developer.hashicorp.com/vault/docs/internals/security)
- [Vault Production Hardening](https://developer.hashicorp.com/vault/tutorials/operations/production-hardening)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)

---

**Remember: Security is not a one-time setup but an ongoing process!**

*Last Updated: December 2025*

