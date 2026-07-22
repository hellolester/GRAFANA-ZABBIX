# Installation Guide

This guide walks through deploying **open-monitoring-stack-grafana-zabbix** on a fresh Ubuntu server.

## 1. Prerequisites

- A fresh install of **Ubuntu Server 22.04 LTS** or **24.04 LTS**
- Root or sudo access
- At least 2 CPU cores, 4 GB RAM, 10 GB free disk space (recommended)
- Outbound internet access to the following repositories:
  - `repo.zabbix.com`
  - `apt.grafana.com`
  - Standard Ubuntu package mirrors

## 2. Clone the repository

```bash
git clone https://github.com/USERNAME/open-monitoring-stack-grafana-zabbix.git
cd open-monitoring-stack-grafana-zabbix
```

## 3. Run the installer

```bash
chmod +x install.sh
sudo ./install.sh
```

You will be prompted for:

| Prompt | Description | Default |
|---|---|---|
| Monitoring server hostname | FQDN or hostname used in Nginx/Grafana config | `monitoring.example.local` |
| System timezone | e.g. `Asia/Kuala_Lumpur`, `America/New_York` | `UTC` |
| Database root password | MariaDB root password | auto-generated if left blank |
| Zabbix DB user password | Password for the `zabbix` MySQL user | auto-generated if left blank |
| Grafana admin password | Initial Grafana `admin` password | auto-generated if left blank |
| Zabbix admin password | Initial Zabbix `Admin` password | auto-generated if left blank |

All values are written to `config/.env` (permissions `600`, root-owned). **This file is never committed to git** — it is listed in `.gitignore`.

## 4. What the installer does

1. Validates the OS and system requirements (`scripts/check_requirements.sh`)
2. Installs base dependencies: curl, snmp tools, ufw, etc. (`scripts/install_dependencies.sh`)
3. Installs and secures MariaDB, creates the Zabbix database (`scripts/install_database.sh`)
4. Installs Zabbix Server 7.0 LTS, Frontend, and Agent 2 from the official repository (`scripts/install_zabbix.sh`)
5. Installs Grafana OSS 11.3.0 from the official repository (`scripts/install_grafana.sh`)
6. Installs the Grafana Zabbix plugin and auto-provisions the datasource + dashboards (`scripts/install_plugins.sh`)
7. Installs and configures Nginx as the frontend web server, enables all services at boot (`scripts/configure_services.sh`)
8. Configures UFW firewall rules (`scripts/configure_firewall.sh`)
9. Runs a full health check (`scripts/health_check.sh`)

The installer is **idempotent** — each step is tracked in `.state/` and will be skipped on re-run unless you delete the corresponding marker file or the whole `.state/` directory.

## 5. Access the stack

After installation completes, the script prints a summary similar to:

```
Grafana:          http://SERVER-IP:3000
Zabbix Frontend:   http://SERVER-IP/zabbix
```

Log in with the credentials stored in `config/.env`.

**Immediately change both admin passwords after first login**, especially if you allowed the installer to auto-generate them.

## 6. Next steps

- [Configuration Guide](configuration.md)
- [SNMP Monitoring Guide](snmp-monitoring.md)
- [Dashboard Guide](dashboards.md)
- [Backup and Restore](backup-restore.md)
- [Troubleshooting](troubleshooting.md)

## 7. Reinstalling / resetting

To force the installer to prompt for new configuration values:

```bash
sudo rm config/.env
sudo rm -rf .state
sudo ./install.sh
```

To fully remove the stack, see [uninstall.sh usage](../README.md#uninstalling).
