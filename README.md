# open-monitoring-stack-grafana-zabbix

A fully automated, open-source, **vendor-neutral** network and infrastructure monitoring platform. Deploys **Zabbix Server 7.0 LTS**, **Grafana OSS 11.3.0**, and the **Grafana Zabbix plugin** on top of MariaDB and Nginx with a single command, on any fresh Ubuntu server.

## Project Overview

This repository turns a blank Ubuntu VM into a production-ready monitoring stack capable of watching routers, switches, firewalls, wireless controllers, servers, virtual machines, storage systems, IoT devices, and any other SNMP-compatible or agent-capable equipment — with no dependency on any specific hardware vendor.

It provides:

- **Zabbix Server 7.0 LTS** + Frontend + Agent 2 for data collection, alerting, and device management
- **Grafana OSS 11.3.0** + the official Grafana Zabbix plugin for visualization
- **MariaDB** as the backing datastore
- **Nginx** as the web front end for the Zabbix UI
- **SNMP (v2c/v3) and ICMP** monitoring support out of the box
- Pre-built, vendor-neutral **Zabbix templates** and **Grafana dashboards**
- Scripts for install, uninstall, update, backup, and restore — all idempotent and safe to re-run

## Architecture

```
Internet / Network Devices
        |
        |  SNMP / API / Agent / ICMP
        v
   Zabbix Server (+ MariaDB)
        |
        |  Zabbix API
        v
   Grafana Dashboard (via Grafana Zabbix plugin)
        |
        v
   You, in a browser
```

Nginx fronts the Zabbix PHP frontend on port 80 (path `/zabbix`); Grafana is served directly on port 3000.

## Installation

### Requirements

- Ubuntu Server **22.04 LTS** or **24.04 LTS**
- Root/sudo access
- 2+ CPU cores, 4+ GB RAM, 10+ GB free disk space (recommended)
- Outbound internet access to `repo.zabbix.com`, `apt.grafana.com`, and standard Ubuntu mirrors

### Deploy

```bash
git clone https://github.com/USERNAME/open-monitoring-stack-grafana-zabbix.git
cd open-monitoring-stack-grafana-zabbix
chmod +x install.sh
sudo ./install.sh
```

You'll be prompted for a hostname, timezone, and passwords (or let the installer auto-generate strong random passwords). Everything is saved to `config/.env` (root-only, git-ignored — never committed).

The installer detects your OS, validates requirements, installs every dependency, sets up the database, installs Zabbix and Grafana, installs the Zabbix plugin, configures Nginx and the firewall, enables all services at boot, and finishes with a health check and an access-info summary.

Full walkthrough: [docs/installation.md](docs/installation.md)

## Access

After installation:

- **Grafana**: `http://SERVER-IP:3000`
- **Zabbix Frontend**: `http://SERVER-IP/zabbix`

Credentials are printed at the end of installation and stored in `config/.env`. **Change both admin passwords immediately after first login.**

## Repository structure

```
open-monitoring-stack-grafana-zabbix/
├── README.md
├── LICENSE
├── install.sh              # main installer
├── uninstall.sh             # removes the stack (optionally purges DB/config)
├── update.sh                 # upgrades Zabbix/Grafana/plugin packages
├── backup.sh                  # backs up database, Grafana data, and config
├── restore.sh                  # restores from a backup.sh snapshot
├── config/
│   ├── .env.example              # environment variable template
│   ├── grafana.ini                 # Grafana config template
│   ├── zabbix_server.conf           # Zabbix server config template
│   ├── nginx.conf                    # Nginx site template
│   └── database.cnf                   # optional MariaDB tuning
├── scripts/
│   ├── common.sh                        # shared logging/helper library
│   ├── check_requirements.sh
│   ├── install_dependencies.sh
│   ├── install_database.sh
│   ├── install_zabbix.sh
│   ├── install_grafana.sh
│   ├── install_plugins.sh
│   ├── configure_firewall.sh
│   ├── configure_services.sh
│   └── health_check.sh
├── dashboards/
│   ├── network-overview.json
│   ├── infrastructure-monitoring.json
│   ├── bandwidth-monitoring.json
│   └── alert-dashboard.json
├── templates/
│   ├── generic-snmp-device.yaml
│   ├── linux-server.yaml
│   └── icmp-monitoring.yaml
├── docs/
│   ├── installation.md
│   ├── configuration.md
│   ├── snmp-monitoring.md
│   ├── dashboards.md
│   ├── backup-restore.md
│   └── troubleshooting.md
└── examples/
    ├── snmp-device-example.md
    └── alert-example.md
```
## Zabbix 7.0 Installation
```
sudo -s

apt update -y

apt install -y wget gnupg mysql-server nginx php8.1-fpm

wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu22.04_all.deb

dpkg -i zabbix-release_latest_7.0+ubuntu22.04_all.deb

apt update -y

apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-nginx-conf zabbix-sql-scripts zabbix-agent

mysql -uroot -p <<EOF
CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
SET GLOBAL log_bin_trust_function_creators = 1;
QUIT;
EOF

zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -ppassword zabbix

mysql -uroot -p <<EOF
SET GLOBAL log_bin_trust_function_creators = 0;
QUIT;
EOF

sed -i 's/# DBPassword=/DBPassword=password/' /etc/zabbix/zabbix_server.conf

sed -i 's/#[[:space:]]*listen[[:space:]]*8080;/listen 8080;/' /etc/zabbix/nginx.conf

sed -i 's/#[[:space:]]*server_name[[:space:]].*/server_name localhost;/' /etc/zabbix/nginx.conf

systemctl restart zabbix-server zabbix-agent nginx php8.1-fpm

systemctl enable zabbix-server zabbix-agent nginx php8.1-fpm

systemctl status zabbix-server --no-pager

echo "======================================"
echo "Zabbix Installation Completed"
echo "Access URL:"
echo "http://YOUR-SERVER-IP:8080"
echo ""
echo "Database:"
echo "Name: zabbix"
echo "User: zabbix"
echo "Password: password"
echo ""
echo "Default Zabbix Login:"
echo "Username: Admin"
echo "Password: zabbix"
echo "======================================"
```

## Grafana 11.3.0 Installation
```
sudo -s

apt-get update -y

apt-get install -y apt-transport-https wget gnupg

mkdir -p /etc/apt/keyrings

wget -O /etc/apt/keyrings/grafana.asc https://apt.grafana.com/gpg-full.key

chmod 644 /etc/apt/keyrings/grafana.asc

echo "deb [signed-by=/etc/apt/keyrings/grafana.asc] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list

apt-get update -y

apt-get install -y grafana

systemctl enable grafana-server

systemctl start grafana-server

grafana-cli plugins install alexanderzobnin-zabbix-app

systemctl restart grafana-server

grafana-cli plugins ls

systemctl status grafana-server --no-pager

echo "======================================"
echo "Grafana Installation Completed"
echo "======================================"
echo ""
echo "Access Grafana:"
echo "http://YOUR-SERVER-IP:3000"
echo ""
echo "Default Login:"
echo "Username: admin"
echo "Password: admin"
echo ""
echo "Installed Plugin:"
echo "alexanderzobnin-zabbix-app"
echo "======================================"
```

## Monitoring capabilities

### Network device monitoring (SNMP)

Availability, CPU, memory, temperature (where exposed), interface status, interface bandwidth, packet errors/drops, uptime, and hardware info — for any SNMP-compatible device. See `templates/generic-snmp-device.yaml`.

### Infrastructure monitoring (agent-based)

CPU, RAM, disk usage, network traffic, service status, and uptime for servers, VMs, and applications via Zabbix Agent 2. See `templates/linux-server.yaml`.

### ICMP monitoring

Simple, agentless up/down and latency checks for devices that don't support SNMP or an agent. See `templates/icmp-monitoring.yaml`.

### Network operations dashboards

Total/online/offline devices, active alerts, bandwidth utilization, availability, latency, and packet loss — see [Dashboard Guide](docs/dashboards.md).

## Dashboard guide

| Dashboard | Purpose |
|---|---|
| **Network Overview** | Fleet-wide device status, bandwidth, errors, latency |
| **Infrastructure Monitoring** | Server/VM CPU, RAM, disk, service status |
| **Bandwidth Monitoring** | Per-interface throughput and packet loss |
| **Alert Dashboard** | Real-time active-problem visibility by severity |

Details: [docs/dashboards.md](docs/dashboards.md)

## SNMP monitoring

Supports SNMP v2c and v3. Covers adding devices, creating credentials, importing templates, and building dashboards.

Full guide: [docs/snmp-monitoring.md](docs/snmp-monitoring.md) · Worked example: [examples/snmp-device-example.md](examples/snmp-device-example.md)

## Alerting

Pre-built triggers ship with every template (device unreachable, high CPU, high memory, interface down, high bandwidth/packet loss, service failure). Configure delivery via Email, Telegram, or generic webhook.

See [examples/alert-example.md](examples/alert-example.md).

## Backup and restore

```bash
sudo ./backup.sh                                  # create a backup
sudo ./restore.sh ./backups/<timestamp-tag>        # restore a backup
```

Details: [docs/backup-restore.md](docs/backup-restore.md)

## Updating

```bash
sudo ./update.sh
```

Automatically takes a pre-update backup, upgrades Zabbix/Grafana/plugin packages, restarts services, and runs a health check.

## Uninstalling

```bash
sudo ./uninstall.sh            # removes Zabbix, Grafana, Nginx config (keeps DB + config/.env)
sudo ./uninstall.sh --purge    # also drops the database and deletes config/.env
```

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md) for common installation, service, SNMP, database, and firewall issues, or run:

```bash
sudo bash scripts/health_check.sh
```

## Security notes

- No hardcoded passwords — all secrets live in `config/.env` (root-only, git-ignored)
- Installer generates strong random passwords by default
- UFW firewall configured to expose only the ports the stack needs, plus SSH
- Unnecessary services (e.g. Apache, if pulled in as a dependency) are disabled
- Default SNMP community strings are never used — a random one is generated per install
- **Change default Grafana/Zabbix admin credentials immediately after first login**

## License

Licensed under the [Apache License 2.0](LICENSE). Built entirely on open-source software installed from official upstream repositories (Zabbix, Grafana, MariaDB, Nginx, Ubuntu).
