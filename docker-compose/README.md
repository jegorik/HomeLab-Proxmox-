# Docker Compose examples for HomeLab services

This directory contains Docker Compose examples and templates intended for use in a Proxmox-hosted home lab. Each subdirectory contains a self-contained service deployment with notes about required environment variables and persistent volumes.

## Included components

- [`checkmk/`](checkmk/) — Checkmk Raw Edition for infrastructure monitoring.
- [`homeassistant/`](homeassistant/) — Home Assistant Container for home automation.
- [`nextcloud(aio)/`](nextcloud(aio)/) — Nextcloud All-In-One (AIO) file sync and collaboration.
- [`nginx-proxy-manager/`](nginx-proxy-manager/) — Nginx Proxy Manager reverse proxy with Let's Encrypt.
- [`prometheus-grafana/`](prometheus-grafana/) — Prometheus + Grafana monitoring stack.
- [`wazuh/`](wazuh/) — Wazuh SIEM/XDR for security monitoring.

## Guidelines

- Review `template.yml` and `.env` files in each service directory before running a Compose file.
- Keep secrets out of the repository. Use a local `.env` file or a secret manager.
- Use `docker compose up -d` from the service directory to start containers.
