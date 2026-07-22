# Example: Adding a Generic SNMP Network Device

This walks through adding a fictional, vendor-neutral network device (e.g. a switch or router) to the monitoring stack. Substitute your own device's IP address and credentials.

## Scenario

- Device IP: `192.168.10.1`
- Device type: any SNMP v2c-capable switch/router/firewall
- Community string: a unique, non-default read-only string (never `public`)

## Step 1: Confirm SNMP connectivity from the monitoring server

```bash
snmpget -v2c -c your_ro_community 192.168.10.1 1.3.6.1.2.1.1.1.0
```

Expected output: a line containing the device's system description string. If this times out, resolve network/firewall/community-string issues before proceeding (see [troubleshooting.md](../docs/troubleshooting.md#snmp-issues)).

## Step 2: Create the host in Zabbix

1. Navigate to **Data collection > Hosts > Create host**
2. **Host name**: `edge-router-01`
3. **Host groups**: `Network Devices` (create if it doesn't exist)
4. Under **Interfaces**, click **Add** next to SNMP:
   - IP address: `192.168.10.1`
   - Port: `161`
   - SNMP version: `SNMPv2`
   - SNMP community: `your_ro_community`
5. Click **Add** to save the host

## Step 3: Attach the generic SNMP template

1. Import `templates/generic-snmp-device.yaml` if you haven't already (**Data collection > Templates > Import**)
2. Go back to the host (`edge-router-01`) > **Templates** tab
3. Link the template `Generic SNMP Device`
4. Save

## Step 4: Verify data is arriving

1. Go to **Monitoring > Latest data**
2. Filter by host `edge-router-01`
3. Within a couple of minutes you should see values populate for:
   - System uptime
   - CPU utilization (if the device exposes UCD-SNMP-MIB)
   - Discovered interfaces (bandwidth, status, errors)

## Step 5: View it on a dashboard

Open Grafana → **Open Monitoring Stack** folder → **Network Overview**. Use the **Host** template variable at the top to select `edge-router-01` and confirm the panels populate.

## Step 6 (optional): Switch to SNMPv3

For production networks, replace the SNMPv2 interface with SNMPv3:

- Security name: your SNMPv3 username
- Security level: `authPriv`
- Auth protocol: SHA-256
- Auth passphrase: (strong, unique)
- Priv protocol: AES-256
- Priv passphrase: (strong, unique)

No template changes are required — the template's items are protocol-version agnostic.
