#!/bin/bash
###############################################################################
# uninstall.sh
# Removes all components installed by this project: Zabbix, Grafana, Nginx
# site config, and optionally MariaDB / the Zabbix database.
#
# Usage:
#   sudo ./uninstall.sh            # keep database and config/.env
#   sudo ./uninstall.sh --purge    # also drop database and delete config/.env
###############################################################################
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/scripts/common.sh"

require_root

PURGE=false
if [[ "${1:-}" == "--purge" ]]; then
    PURGE=true
fi

echo ""
log_warn "This will stop and remove Zabbix, Grafana, and the Nginx site configuration."
if [[ "${PURGE}" == "true" ]]; then
    log_warn "PURGE MODE: the Zabbix database and config/.env will also be permanently deleted."
fi
read -rp "Type 'yes' to continue: " CONFIRM
if [[ "${CONFIRM}" != "yes" ]]; then
    log_info "Aborted."
    exit 0
fi

step "Stopping services"
for svc in zabbix-server zabbix-agent2 grafana-server nginx snmpd; do
    systemctl stop "${svc}" 2>/dev/null || true
    systemctl disable "${svc}" 2>/dev/null || true
done

step "Removing Zabbix packages"
wait_for_apt_lock
DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y \
    'zabbix-*' 2>&1 | tee -a "${LOG_FILE}" || true

step "Removing Grafana package"
wait_for_apt_lock
DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y grafana 2>&1 | tee -a "${LOG_FILE}" || true

step "Removing Nginx site configuration"
rm -f /etc/nginx/sites-enabled/zabbix-monitoring.conf
rm -f /etc/nginx/sites-available/zabbix-monitoring.conf
systemctl restart nginx 2>/dev/null || true

if [[ "${PURGE}" == "true" ]]; then
    step "Dropping Zabbix database"
    if [[ -f "${REPO_ROOT}/config/.env" ]]; then
        load_env
        mysql -uroot -p"${DB_ROOT_PASSWORD}" -e "DROP DATABASE IF EXISTS ${DB_NAME}; DROP USER IF EXISTS '${DB_USER}'@'localhost'; FLUSH PRIVILEGES;" 2>&1 | tee -a "${LOG_FILE}" || log_warn "Could not drop database automatically."
    fi

    step "Removing MariaDB package"
    wait_for_apt_lock
    DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y mariadb-server mariadb-client 2>&1 | tee -a "${LOG_FILE}" || true

    step "Deleting configuration and state"
    rm -f "${REPO_ROOT}/config/.env"
    rm -rf "${REPO_ROOT}/.state"
    log_ok "Configuration and state removed."
else
    log_warn "Database and config/.env preserved. Re-run with --purge to remove them."
fi

step "Cleaning up unused packages"
wait_for_apt_lock
apt-get autoremove -y 2>&1 | tee -a "${LOG_FILE}" || true

log_ok "Uninstallation completed."
