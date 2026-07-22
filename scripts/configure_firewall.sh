#!/bin/bash
###############################################################################
# configure_firewall.sh
# Configures UFW to allow only the ports required by the monitoring stack
# plus SSH, and enables the firewall. Idempotent.
###############################################################################
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

require_root
load_env

if [[ "${ENABLE_FIREWALL:-true}" != "true" ]]; then
    log_warn "ENABLE_FIREWALL is not 'true'. Skipping firewall configuration."
    exit 0
fi

step "Configuring UFW firewall rules"

# Always keep SSH open first to avoid lockout
ufw allow "${FIREWALL_ALLOW_SSH_PORT:-22}/tcp" comment "SSH"

# Web (Nginx / Zabbix frontend)
ufw allow "${WEB_LISTEN_PORT:-80}/tcp" comment "Nginx / Zabbix frontend"

# Grafana
ufw allow "${GRAFANA_PORT:-3000}/tcp" comment "Grafana"

# Zabbix server (agent -> server, active/passive checks)
ufw allow "${ZABBIX_SERVER_PORT:-10051}/tcp" comment "Zabbix server"

# Zabbix agent (server -> agent, passive checks)
ufw allow "${ZABBIX_AGENT_PORT:-10050}/tcp" comment "Zabbix agent"

# SNMP (outbound polling handled by default outgoing policy; open inbound traps if used)
ufw allow 162/udp comment "SNMP traps"

step "Setting default policies"
ufw default deny incoming
ufw default allow outgoing

step "Enabling UFW"
ufw --force enable

ufw status verbose | tee -a "${LOG_FILE}"

log_ok "Firewall configuration completed."
