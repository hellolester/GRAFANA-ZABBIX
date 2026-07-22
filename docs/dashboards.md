# Dashboard Guide

Four pre-built dashboards are provisioned automatically into Grafana under the **Open Monitoring Stack** folder. They are stored as JSON in `dashboards/` and loaded via Grafana's file-based provisioning (`/etc/grafana/provisioning/dashboards/`).

## 1. Network Overview (`network-overview.json`)

High-level view across all monitored network equipment:

- Total monitored devices / online / offline / active alerts (stat panels)
- Interface bandwidth (in/out) across all devices
- Interface errors and discards (table)
- Network latency (ICMP round-trip time)

Filter using the **Host Group** and **Host** template variables at the top of the dashboard.

## 2. Infrastructure Monitoring (`infrastructure-monitoring.json`)

Server / VM / application-focused view (data from Zabbix Agent 2):

- CPU utilization
- Memory utilization
- Disk space usage
- Network traffic
- Service status table
- System uptime

## 3. Bandwidth Monitoring (`bandwidth-monitoring.json`)

Deep-dive into network throughput:

- Inbound bandwidth per interface
- Outbound bandwidth per interface
- Packet errors (in/out)
- Packet drops/discards

Includes an additional **Interface** template variable for filtering to a specific port.

## 4. Alert Dashboard (`alert-dashboard.json`)

Real-time operational awareness of Zabbix problems:

- Active problem counts by severity (Disaster / High / Average / Warning)
- Total active problems
- Current problems table (sorted by priority)
- Problem count trend over time

## Customizing dashboards

Because dashboards are provisioned from files with `allowUiUpdates: true`, you can edit them directly in the Grafana UI and save changes — they persist in Grafana's own database. To make changes permanent and version-controlled, export the dashboard JSON (**Dashboard settings > JSON Model**) and overwrite the corresponding file in `dashboards/`, then either wait for the 30-second provisioning refresh or restart Grafana:

```bash
sudo systemctl restart grafana-server
```

## Adding a new dashboard

1. Build the dashboard in Grafana as normal, using the **Zabbix** datasource
2. Export the JSON model
3. Save it into `dashboards/your-dashboard-name.json`
4. Copy it into the provisioning path and restart Grafana, or re-run:
   ```bash
   sudo bash scripts/install_plugins.sh
   ```
   which re-copies all files from `dashboards/` into the provisioned directory.
