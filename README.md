# HomeLab (Proxmox) configuration collection

This repository is a curated collection of configuration files and deployment
templates for a Proxmox-based home laboratory. Its purpose is to gather
reliable, reusable examples (Docker Compose, container templates, environment
files) that simplify deploying services in a homelab environment managed by
Proxmox and/or Docker.

The repository is maintained as a living document: new configurations and
templates will be added over time. Use the links below to navigate to folder
examples and find concise guidance for each component.

## Directories

- [`docker-compose/`](docker-compose/) — Docker Compose examples and templates.
  - [`checkmk/`](docker-compose/checkmk/) — Checkmk Raw Edition for infrastructure monitoring.
  - [`homeassistant/`](docker-compose/homeassistant/) — Home Assistant Container for home automation.
  - [`nextcloud(aio)/`](docker-compose/nextcloud(aio)/) — Nextcloud All-In-One (AIO) file sync and collaboration.
  - [`nginx-proxy-manager/`](docker-compose/nginx-proxy-manager/) — Nginx Proxy Manager for reverse proxy with Let's Encrypt.
  - [`prometheus-grafana/`](docker-compose/prometheus-grafana/) — Prometheus + Grafana monitoring stack with Node Exporter.
  - [`wazuh/`](docker-compose/wazuh/) — Wazuh SIEM/XDR for security monitoring and threat detection.

## How to use

- Review the `template.yml` and `.env` files before running a Compose file.
- Store secrets (passwords, tokens) in a local `.env` or a secret manager — do not commit sensitive data to the repository.
- Run Compose files from the directory where they live: `docker compose up -d`.

## Contributing

- If you add a new configuration, include a short `README.md` in the new folder with usage notes and any required host prerequisites (volumes, ports).

## License

- This repository contains configuration examples; verify licensing for any upstream images or components you use in production.

---

This README will be extended as new components are added.
