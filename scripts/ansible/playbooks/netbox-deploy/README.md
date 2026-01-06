# NetBox Deployment Playbook

Automated deployment of NetBox DCIM/IPAM platform on Debian 13 LXC container using Ansible.

## Overview

This playbook deploys **NetBox v4.4.9** with the following components:

- **PostgreSQL 17** - Primary database
- **Redis** - Caching and task queue
- **NetBox** - DCIM/IPAM application
- **Gunicorn** - WSGI application server
- **Nginx** - Reverse proxy web server
- **Systemd** - Service management

## Prerequisites

### Infrastructure

- LXC container created by Terraform ([`terraform/lxc-netbox`](../../../../terraform/lxc-netbox/README.md))
- Debian 13 (Trixie) operating system
- SSH access configured with Ansible user
- Container added to `inventory.yml` (copy from Terraform output: `tofu output ansible_inventory_entry`)

### Secrets Management

- HashiCorp Vault accessible and unsealed
- `VAULT_ADDR` environment variable set
- `VAULT_TOKEN` environment variable set with valid token
- All secrets are auto-generated and stored in Vault at configured path
- Stored secrets include:
  - `db_password` - PostgreSQL database password
  - `db_user` - PostgreSQL database username
  - `db_name` - PostgreSQL database name
  - `db_host` - PostgreSQL database host
  - `db_port` - PostgreSQL database port
  - `secret_key` - Django SECRET_KEY (50 characters)
  - `superuser_username` - NetBox admin username
  - `superuser_password` - NetBox admin password (24 characters)
  - `superuser_email` - NetBox admin email

### Ansible Collections

```bash
ansible-galaxy collection install community.hashi_vault
ansible-galaxy collection install community.postgresql
```

## Usage

### Deploy NetBox

Run the complete deployment:

```bash
cd scripts/ansible
ansible-playbook playbooks/netbox-deploy/site.yml
```

### Run Specific Roles

Deploy only specific components using tags:

```bash
# Install only PostgreSQL
ansible-playbook playbooks/netbox-deploy/site.yml --tags postgresql

# Install PostgreSQL and Redis
ansible-playbook playbooks/netbox-deploy/site.yml --tags database,cache

# Configure Nginx only
ansible-playbook playbooks/netbox-deploy/site.yml --tags nginx

# Create superuser only
ansible-playbook playbooks/netbox-deploy/site.yml --tags superuser
```

Available tags:

- `postgresql`, `database` - PostgreSQL installation
- `redis`, `cache` - Redis installation
- `netbox`, `application` - NetBox application
- `systemd`, `services` - Systemd service units
- `nginx`, `webserver` - Nginx reverse proxy
- `superuser`, `admin` - Django admin account

### Verify Deployment

Check service status:

```bash
ansible netbox -m shell -a "systemctl status netbox netbox-rq nginx"
```

Test NetBox API:

```bash
curl http://<container-ip>/api/
```

## Roles

### postgresql

Installs PostgreSQL 17 from Debian repositories and configures:

- Database: `netbox`
- User: `netbox`
- Password: Auto-generated and stored in Vault
- Authentication: MD5 for local connections

### redis

Installs and configures Redis:

- Binding: localhost only
- Databases: 0 (tasks), 1 (caching)
- Memory: 256MB limit with LRU eviction
- Persistence: Disabled (cache-only)

### netbox

Deploys NetBox application:

- Version: v4.4.9 (from GitHub)
- Installation: `/opt/netbox`
- Virtual environment: Python 3.11
- Configuration: Auto-generated from template
- SECRET_KEY: 50-character random string in Vault
- Migrations: Automatic database schema updates
- Static files: Collected for Nginx serving

### systemd

Creates systemd service units:

- `netbox.service` - Gunicorn WSGI server (port 8001)
- `netbox-rq.service` - Background task worker
- Auto-restart on failure
- Dependency management (PostgreSQL, Redis)

### nginx

Configures Nginx reverse proxy:

- Port detection: 80 (primary) or 8300 (fallback)
- Static files: Direct serving from `/opt/netbox/netbox/static/`
- Media files: Direct serving from `/opt/netbox/netbox/media/`
- Proxy: Forward to Gunicorn on port 8001
- Headers: X-Forwarded-* for proper client IP

### superuser

Creates Django admin account:

- Username: `admin` (default)
- Password: Auto-generated 24-character string
- Email: `admin@localhost`
- Credentials: Stored in Vault at `secret/netbox/superuser`

## Post-Deployment

### Access NetBox

Web UI: `http://<container-ip>` (port 80 or 8300)

### Retrieve Credentials from Vault

Get all NetBox credentials:

```bash
vault kv get secret/netbox
# Or use the path configured in your playbook:
vault kv get secrets/proxmox/netbox
```

Output includes:

```text
====== Data ======
Key                   Value
---                   -----
db_host               localhost
db_name               netbox
db_password           <32-character-password>
db_port               5432
db_user               netbox
secret_key            <50-character-secret>
superuser_email       admin@localhost
superuser_password    <24-character-password>
superuser_username    admin
```

### Connect to PostgreSQL Database

Using credentials from Vault:

```bash
# Get database password
export PGPASSWORD=$(vault kv get -field=db_password secrets/proxmox/netbox)

# Connect to database
psql -h localhost -U netbox -d netbox
```

### Initial Configuration

1. Login to NetBox web UI
2. Configure site settings (Admin → System → Configuration)
3. Add sites, racks, device types
4. Import initial data if available
5. Create additional user accounts

## Troubleshooting

### Check Service Logs

```bash
# NetBox application
journalctl -u netbox -f

# Background worker
journalctl -u netbox-rq -f

# Nginx
journalctl -u nginx -f

# PostgreSQL
journalctl -u postgresql -f
```

### Manual Service Management

```bash
# Restart NetBox services
systemctl restart netbox netbox-rq

# Check service status
systemctl status netbox netbox-rq nginx postgresql redis-server

# View running processes
ps aux | grep -E 'gunicorn|rqworker|nginx'
```

### Database Access

```bash
# Connect to PostgreSQL
sudo -u postgres psql netbox

# Check database size
sudo -u postgres psql -c "\l+ netbox"

# Check connections
sudo -u postgres psql -c "SELECT * FROM pg_stat_activity WHERE datname='netbox';"
```

### Common Issues

**Issue**: Nginx shows 502 Bad Gateway

**Solution**: Check if Gunicorn is running:

```bash
systemctl status netbox
journalctl -u netbox -n 50
```

---

**Issue**: Database connection failed

**Solution**: Verify PostgreSQL is running and credentials are correct:

```bash
systemctl status postgresql
vault kv get secret/netbox/db_password
```

---

**Issue**: Static files not loading

**Solution**: Re-collect static files:

```bash
sudo -u netbox /opt/netbox/venv/bin/python /opt/netbox/netbox/manage.py collectstatic --no-input
```

## Configuration Files

### NetBox Configuration

Location: `/opt/netbox/netbox/netbox/configuration.py`

Key settings:

- `ALLOWED_HOSTS = ['*']` - For testing (change in production)
- `DATABASE` - PostgreSQL connection details
- `REDIS` - Cache and task queue configuration
- `SECRET_KEY` - Cryptographic signing key

### Systemd Units

- `/etc/systemd/system/netbox.service` - Gunicorn WSGI server
- `/etc/systemd/system/netbox-rq.service` - Background worker

### Nginx Configuration

- `/etc/nginx/sites-available/netbox` - NetBox site configuration
- `/etc/nginx/sites-enabled/netbox` - Enabled site symlink

## Architecture

```text
Internet/Network
       │
       ▼
   [Nginx:80/8300] ◄── Static/Media files from /opt/netbox/netbox/
       │
       ▼
[Gunicorn:8001] ◄── NetBox Django Application
       │
       ├──► [PostgreSQL:5432] - Database
       │
       └──► [Redis:6379] - Cache & Tasks
              │
              └──► [NetBox-RQ Worker] - Background jobs
```

## Security Considerations

1. **ALLOWED_HOSTS**: Change from `['*']` to specific domains in production
2. **SECRET_KEY**: Never expose, always stored in Vault
3. **Database Password**: Auto-generated 32 characters, stored in Vault
4. **Admin Password**: Auto-generated 24 characters, stored in Vault
5. **Redis**: Localhost binding only, no authentication (internal)
6. **PostgreSQL**: MD5 authentication, local connections only

## Idempotency

All roles are designed to be fully idempotent:

- ✓ Safe to run multiple times
- ✓ No duplicate database entries
- ✓ Configuration updates applied correctly
- ✓ Services restarted only when needed

## References

- [NetBox Documentation](https://docs.netbox.dev/)
- [NetBox Installation Guide](https://docs.netbox.dev/en/stable/installation/)
- [NetBox GitHub Repository](https://github.com/netbox-community/netbox)
- [Ansible Documentation](https://docs.ansible.com/)
- [HashiCorp Vault](https://www.vaultproject.io/docs)
