# Example: Configuring Alerts and Notifications

This example configures Zabbix to send a notification when a device becomes unreachable, using the built-in triggers already shipped with the templates in `templates/`.

## Triggers already included

| Template | Trigger | Severity |
|---|---|---|
| `generic-snmp-device.yaml` | Device unreachable via SNMP (`nodata` on uptime) | High |
| `generic-snmp-device.yaml` | High CPU utilization (>85% for 5m) | Warning |
| `generic-snmp-device.yaml` | Interface down | Average |
| `icmp-monitoring.yaml` | Device unreachable via ICMP ping | Disaster |
| `icmp-monitoring.yaml` | High packet loss (>20%) | Average |
| `icmp-monitoring.yaml` | High ICMP latency (>200ms) | Warning |
| `linux-server.yaml` | High CPU utilization | Warning |
| `linux-server.yaml` | Low available memory (<10%) | High |
| `linux-server.yaml` | Disk space critically low (>90% used) | High |
| `linux-server.yaml` | Agent unavailable / host unreachable | High |

These fire automatically once a host has the relevant template attached — no extra configuration needed to *generate* the alert. The steps below configure Zabbix to *notify* you when they fire.

## Option A: Email notifications

1. **Alerts > Media types > Email** — edit the built-in Email media type with your SMTP details (matching `NOTIFY_EMAIL_*` in `config/.env` if you filled those in):
   - SMTP server / port
   - From address
   - Authentication (if required)
2. **Users > [your user] > Media** tab — add Email media, enter your address, and set "Use if severity" to at least Warning
3. **Alerts > Actions > Trigger actions** — ensure the default "Report problems to Zabbix administrators" action is enabled, or create a new action:
   - Conditions: Trigger severity `>=` Warning
   - Operations: Send message to your user group via Email

## Option B: Telegram notifications

1. Create a Telegram bot via **@BotFather** and note the bot token
2. Get your chat ID (message the bot, then check `https://api.telegram.org/bot<token>/getUpdates`)
3. In Zabbix: **Alerts > Media types > Telegram** (or import the official Telegram media type template if not present)
4. Set the bot token in the media type configuration
5. **Users > [your user] > Media** — add Telegram media with your chat ID
6. Confirm a trigger action routes to your user/user group as in Option A

## Option C: Generic webhook

1. **Alerts > Media types > Create media type**
2. Type: `Webhook`
3. Configure the webhook URL (matching `NOTIFY_WEBHOOK_URL` in `config/.env` if set) and the JSON payload template — Zabbix's webhook media type supports macros like `{ALERT.SUBJECT}`, `{ALERT.MESSAGE}`, `{TRIGGER.STATUS}`
4. Attach to a user's media and confirm a trigger action includes that user

## Testing an alert end-to-end

The fastest way to test the pipeline without waiting for a real outage: temporarily block ICMP/SNMP from the monitored device to the monitoring server (e.g. a temporary firewall rule on the device), and confirm:

1. The trigger fires in **Monitoring > Problems**
2. A notification arrives via your configured media (email/Telegram/webhook)
3. Remove the temporary block and confirm the problem resolves and a "resolved" notification arrives (if configured)
