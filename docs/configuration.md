# Configuration Guide

## Environment file: `config/.env`

All installer-generated values live in `config/.env`, created from `config/.env.example` on first run. Key variables:

```dotenv
MONITORING_HOSTNAME=monitoring.example.local
SYSTEM_TIMEZONE=Asia/Kuala_Lumpur

DB_ROOT_PASSWORD=...
DB_NAME=zabbix
DB_USER=zabbix
DB_PASSWORD=...

ZABBIX_VERSION=7.0
ZABBIX_ADMIN_USER=Admin
ZABBIX_ADMIN_PASSWORD=...

GRAFANA_VERSION=11.3.0
GRAFANA_PORT=3000
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=...
GRAFANA_ZABBIX_PLUGIN=alexanderzobnin-zabbix-app

WEB_LISTEN_PORT=80
ZABBIX_URL_PATH=/zabbix

ENABLE_FIREWALL=true
FIREWALL_ALLOW_SSH_PORT=22
```

This file is `chmod 600`, root-owned, and excluded from version control via `.gitignore`. Treat it as a secrets file.

## Configuration file locations after install

| Component | File |
|---|---|
| Zabbix Server | `/etc/zabbix/zabbix_server.conf` |
| Zabbix Agent 2 | `/etc/zabbix/zabbix_agent2.conf` |
| Grafana | `/etc/grafana/grafana.ini` |
| Grafana provisioning (datasource) | `/etc/grafana/provisioning/datasources/zabbix.yaml` |
| Grafana provisioning (dashboards) | `/etc/grafana/provisioning/dashboards/open-monitoring-stack.yaml` |
| Nginx site | `/etc/nginx/sites-available/zabbix-monitoring.conf` |
| SNMP daemon (local) | `/etc/snmp/snmpd.conf` |

The versions in `config/` (this repository) are **templates** with `{{PLACEHOLDER}}` tokens substituted by the install scripts. Editing the repository templates and re-running the relevant `scripts/install_*.sh` script will re-apply your changes.

## Changing the web port or hostname after install

1. Edit `config/.env` and update `MONITORING_HOSTNAME` / `WEB_LISTEN_PORT` / `GRAFANA_PORT`.
2. Re-run the relevant script directly, e.g.:
   ```bash
   sudo bash scripts/configure_services.sh
   sudo bash scripts/install_grafana.sh
   ```
   (Re-running these scripts is safe; they overwrite the generated config files with updated values and restart the affected services.)

## Database tuning

`config/database.cnf` contains optional MariaDB performance tuning suitable for a dedicated monitoring host. It is **not applied automatically** to avoid overriding safe defaults on small VMs. To apply it:

```bash
sudo cp config/database.cnf /etc/mysql/mariadb.conf.d/61-tuning.cnf
sudo systemctl restart mariadb
```

Adjust `innodb_buffer_pool_size` to match available RAM before applying.

## Notification channels

Email, Telegram, and webhook notification variables in `config/.env` are optional placeholders. Configuring them in Zabbix's web UI (**Alerts > Media types**) is covered in the [Alerting section of the README](../README.md#alerting) and [examples/alert-example.md](../examples/alert-example.md).
