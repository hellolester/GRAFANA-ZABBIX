# SNMP Monitoring Guide

This platform is **vendor-neutral**: it monitors any device that speaks standard SNMP (MIB-II / Host Resources MIB), regardless of manufacturer — routers, switches, firewalls, wireless controllers, storage systems, IoT devices, or anything else on the network.

## Supported SNMP versions

- **SNMP v2c** — community-string based, simplest to set up
- **SNMP v3** — authentication + encryption (`authPriv`), recommended for production networks

## 1. Adding a device in Zabbix

1. Log in to the Zabbix frontend at `http://SERVER-IP/zabbix`
2. Go to **Data collection > Hosts > Create host**
3. Fill in:
   - **Host name**: a descriptive name, e.g. `core-switch-01`
   - **Host groups**: create or select a group, e.g. `Network Devices`
   - **Interfaces**: click **Add** next to SNMP, enter the device's IP address, port `161`

## 2. Creating SNMP credentials

### SNMP v2c

In the SNMP interface configuration:
- **SNMP version**: SNMPv2
- **SNMP community**: your read-only community string (never use `public` in production — generate a unique string per environment)

### SNMP v3

In the SNMP interface configuration:
- **SNMP version**: SNMPv3
- **Security name**: the SNMPv3 username configured on the device
- **Security level**: `authPriv` (recommended)
- **Authentication protocol**: SHA-256 (or the strongest supported by your device)
- **Authentication passphrase**: a strong, unique passphrase
- **Privacy protocol**: AES-256 (or the strongest supported)
- **Privacy passphrase**: a strong, unique passphrase

Store SNMPv3 credentials the same way you'd store any other production secret — do not commit them to the repository.

## 3. Importing templates

This repository ships three vendor-neutral templates in `templates/`:

| Template file | Use for |
|---|---|
| `generic-snmp-device.yaml` | Any SNMP-compatible network device (routers, switches, firewalls, wireless controllers, storage, IoT) |
| `linux-server.yaml` | Servers/VMs monitored via Zabbix Agent 2 |
| `icmp-monitoring.yaml` | Simple up/down + latency checks for devices without SNMP/agent support |

To import:

1. Go to **Data collection > Templates > Import**
2. Select the `.yaml` file from the `templates/` directory
3. Click **Import**
4. Attach the imported template to your host under **Data collection > Hosts > [your host] > Templates**

### What `generic-snmp-device.yaml` monitors

- Device availability (via `sysUpTime` polling + `nodata()` trigger)
- System description, contact, and location (MIB-II)
- CPU utilization (UCD-SNMP-MIB, widely implemented)
- Memory total/available
- Automatic interface discovery (IF-MIB `ifTable`) with per-interface:
  - Operational status (up/down)
  - Inbound/outbound bandwidth
  - Inbound/outbound errors
  - Inbound/outbound discards

All OIDs used are from standard, vendor-neutral MIBs (MIB-II, IF-MIB, Host Resources / UCD-SNMP-MIB). No vendor-proprietary MIBs are required.

## 4. Creating dashboards

Once a host has data flowing in:

1. Open Grafana at `http://SERVER-IP:3000`
2. Import or open a pre-provisioned dashboard from the **Open Monitoring Stack** folder (auto-loaded from `dashboards/`)
3. Use the **Host Group** / **Host** template variables at the top of each dashboard to filter to your device(s)
4. To build a custom panel, add a new panel with datasource **Zabbix**, and select **Item** queries filtered by host/item-key pattern (e.g. `/Interface .*: Bits (received|sent)/`)

## 5. Discovering devices automatically (optional)

Zabbix supports **network discovery** to automatically find and register SNMP-reachable devices on a subnet:

1. Go to **Data collection > Discovery > Create discovery rule**
2. Define an IP range (e.g. `192.168.1.1-254`)
3. Add an SNMP agent check with your community string / SNMPv3 credentials
4. Pair with an **action** (Data collection > Actions > Discovery actions) to auto-add discovered hosts and link the `Generic SNMP Device` template

## 6. Troubleshooting SNMP

See [troubleshooting.md](troubleshooting.md#snmp-issues) for common SNMP connectivity problems.
