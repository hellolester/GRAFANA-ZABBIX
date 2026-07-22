# Backup and Restore

## Creating a backup

```bash
sudo ./backup.sh
```

This creates a timestamped directory under `backups/`, for example:

```
backups/20260722-101500-manual/
├── zabbix-db.sql.gz          # full MariaDB dump of the Zabbix database
├── grafana-data.tar.gz       # Grafana's /var/lib/grafana directory
├── config/
│   ├── grafana.ini
│   ├── grafana-provisioning/
│   ├── zabbix_server.conf
│   ├── zabbix_agent2.conf
│   ├── zabbix-monitoring.conf
│   └── .env.bak
└── manifest.txt
```

`update.sh` automatically calls `backup.sh --pre-update` before applying any package upgrades, so you always have a rollback point.

### Recommended practice

- Schedule `backup.sh` via cron for regular snapshots:
  ```bash
  sudo crontab -e
  # Daily backup at 2 AM
  0 2 * * * /path/to/open-monitoring-stack-grafana-zabbix/backup.sh >> /var/log/monitoring-backup.log 2>&1
  ```
- Copy the `backups/` directory off-host regularly (rsync, object storage, etc.) — a local backup does not protect against disk or host failure.
- The `.env.bak` copy inside each backup contains secrets; keep backup storage as tightly controlled as the live server.

## Restoring a backup

```bash
sudo ./restore.sh ./backups/20260722-101500-manual
```

This will:

1. Stop Zabbix Server and Grafana
2. Restore the Zabbix database from `zabbix-db.sql.gz`
3. Restore `/var/lib/grafana` from `grafana-data.tar.gz` (the previous directory is preserved as `/var/lib/grafana.old.<timestamp>` rather than deleted)
4. Restore Grafana, Zabbix, and Nginx configuration files
5. Restart all services and run a health check

You will be asked to confirm before any destructive action is taken.

## Disaster recovery on a new host

1. Provision a fresh Ubuntu 22.04/24.04 server
2. Clone this repository and run `sudo ./install.sh` to get a working baseline stack (use a fresh `config/.env`, or restore your old one to `config/.env` first for matching credentials)
3. Copy your backup directory onto the new host
4. Run `sudo ./restore.sh <backup-directory>`
