#!/bin/bash
###############################################################################
# update.sh
# Updates Zabbix, Grafana, and the Grafana Zabbix plugin to the latest
# packages available in their respective official repositories, then
# restarts services and runs a health check.
#
# Usage:
#   sudo ./update.sh
###############################################################################
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/scripts/common.sh"

require_root
load_env

step "Backing up before update"
bash "${SCRIPT_DIR}/backup.sh" --pre-update || log_warn "Pre-update backup failed; continuing with update at your own risk."

step "Refreshing package index"
wait_for_apt_lock
apt-get update -y | tee -a "${LOG_FILE}"

step "Upgrading Zabbix packages"
wait_for_apt_lock
DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade 'zabbix-*' 2>&1 | tee -a "${LOG_FILE}" || log_warn "No Zabbix package upgrades available or upgrade failed."

step "Upgrading Grafana package"
wait_for_apt_lock
DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade grafana 2>&1 | tee -a "${LOG_FILE}" || log_warn "No Grafana package upgrade available or upgrade failed."

step "Updating Grafana Zabbix plugin"
grafana-cli plugins update-all 2>&1 | tee -a "${LOG_FILE}" || log_warn "Plugin update encountered an issue."

step "Restarting services"
systemctl restart zabbix-server zabbix-agent2 grafana-server nginx

step "Running post-update health check"
bash "${SCRIPT_DIR}/scripts/health_check.sh"

log_ok "Update completed successfully."
