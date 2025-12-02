# LXC Grafana Container - Terraform/OpenTofu Configuration

This Terraform/OpenTofu configuration deploys a Grafana monitoring dashboard
in an unprivileged LXC container on Proxmox VE.

## Features

- **Unprivileged Container**: Enhanced security with user namespace isolation
- **Ubuntu 24.04 LTS**: Stable and long-term supported base image
- **Grafana OSS**: Official Grafana installation from APT repository
- **Automated Setup**: Grafana installed and configured via provisioner
- **SSH Key Authentication**: Secure access without password
- **Generated Passwords**: Strong random passwords for root and Grafana admin
- **Remote State**: PostgreSQL backend for team collaboration

## Prerequisites

### Proxmox VE Requirements

- Proxmox VE 8.x or 9.x
- API token with the following permissions:
  - `Datastore.AllocateSpace`
  - `Datastore.AllocateTemplate`
  - `Datastore.Audit`
  - `SDN.Use`
  - `Sys.Audit`
  - `Sys.Console`
  - `VM.Allocate`
  - `VM.Audit`
  - `VM.Config.*`
  - `VM.PowerMgmt`

### LXC Template

Download the Ubuntu template before applying:

```bash
# List available templates
pveam available | grep ubuntu

# Download Ubuntu 24.04 template
pveam download local ubuntu-24.04-standard_24.04-2_amd64.tar.zst
```

### Local Requirements

- OpenTofu >= 1.5.0 or Terraform >= 1.5.0
- SSH key pair (`~/.ssh/id_rsa.pub` by default)
- Network access to Proxmox API and container network

### Backend Requirements (Optional)

For remote state storage:

- PostgreSQL 12+ database
- Database credentials in `pg.backend.conf`

## Quick Start

### 1. Clone and Configure

```bash
cd terraform/lxc-grafana

# Copy example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

### 2. Configure Backend (Optional)

For PostgreSQL backend, create `pg.backend.conf`:

```ini
conn_str = "postgres://user:password@host:5432/database?sslmode=disable"
```

For local state, comment out the backend block in `backend.tf`.

### 3. Initialize and Apply

```bash
# Initialize with PostgreSQL backend
tofu init -backend-config=pg.backend.conf

# Or initialize with local state
tofu init

# Review planned changes
tofu plan

# Apply infrastructure
tofu apply
```

### 4. Access Grafana

```bash
# Get Grafana admin password
tofu output -raw grafana_admin_password

# Get container IP (if using DHCP, check Proxmox GUI)
tofu output grafana_url

# Open in browser
# http://<container-ip>:3000
```

Default credentials:

- **Username**: `admin` (or value of `grafana_admin_user`)
- **Password**: Run `tofu output -raw grafana_admin_password`

## File Structure

| File | Description |
|------|-------------|
| `main.tf` | LXC container resource and Grafana installation |
| `variables.tf` | Input variable definitions with validations |
| `outputs.tf` | Output values (URLs, passwords, resource summary) |
| `providers.tf` | Provider configuration (bpg/proxmox v0.88.0) |
| `backend.tf` | PostgreSQL state backend configuration |
| `terraform.tfvars.example` | Example variable values |

## Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `proxmox_endpoint` | Proxmox API URL | - |
| `proxmox_api_token` | API token | - |
| `lxc_id` | Container ID (VMID) | 200 |
| `lxc_hostname` | Container hostname | grafana |
| `lxc_cpu_cores` | CPU cores | 1 |
| `lxc_memory` | Memory in MB | 1024 |
| `lxc_disk_size` | Disk size in GB | 8 |
| `grafana_port` | Grafana HTTP port | 3000 |
| `grafana_admin_user` | Admin username | admin |

See `variables.tf` for the complete list with descriptions.

## Security Best Practices

This configuration implements several security measures:

1. **Unprivileged Container** - Runs with user namespace isolation
2. **No Root Password Login** - SSH key authentication only
3. **Generated Passwords** - Strong random passwords (16+ chars)
4. **Minimal Resources** - Only allocated what's needed
5. **Grafana Hardening**:
   - Anonymous access disabled by default
   - Gravatar disabled
   - Custom admin credentials

### Additional Recommendations

- Use a reverse proxy (Nginx Proxy Manager) with HTTPS
- Configure Grafana alerting for security events
- Regularly update Grafana: `apt update && apt upgrade grafana`
- Back up Grafana database: `/var/lib/grafana/grafana.db`

## Integration with Prometheus

To connect Grafana with Prometheus from the docker-compose stack:

1. Open Grafana → Configuration → Data Sources
2. Add data source → Prometheus
3. URL: `http://<prometheus-host>:9090`
4. Save & Test

## Troubleshooting

### Container Won't Start

```bash
# Check Proxmox logs
journalctl -u pve-container@<vmid> -f

# Verify template exists
pveam list local | grep ubuntu
```

### Grafana Service Issues

```bash
# SSH into container
ssh root@<container-ip>

# Check Grafana status
systemctl status grafana-server

# View logs
journalctl -u grafana-server -f

# Restart service
systemctl restart grafana-server
```

### Cannot Connect to Grafana

1. Verify container is running in Proxmox GUI
2. Check container has IP: `lxc-info -n <vmid>`
3. Verify port is listening: `ss -tlnp | grep 3000`
4. Check firewall rules on Proxmox host

### Password Reset

```bash
# SSH into container
ssh root@<container-ip>

# Reset Grafana admin password
grafana-cli admin reset-admin-password <new-password>
```

## Provider Documentation

- [bpg/proxmox Provider](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
- [Proxmox LXC Documentation](https://pve.proxmox.com/wiki/Linux_Container)
- [Grafana Installation](https://grafana.com/docs/grafana/latest/setup-grafana/installation/debian/)

## Proxmox VE 9.1 Note

Proxmox VE 9.1 (November 2025) introduces support for creating LXC containers
from OCI images. This configuration uses the traditional LXC template approach
for maximum compatibility. For OCI-based deployment, see the Proxmox documentation.

## License

This configuration is provided as-is. Verify licensing for Ubuntu images
and Grafana in production environments.
