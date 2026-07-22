#!/bin/bash
###############################################################################
# restore.sh
# Restores a backup created by backup.sh.
#
# Usage:
#   sudo ./restore.sh ./backups/20260722-101500-manual
###############################################################################
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/scripts/common.sh"

require_root
load_env

BACKUP_PATH="${1:-}"
if [[ -z "${BACKUP_PATH}" ]]; then
    die "Usage: sudo ./restore.sh <path-to-backup-directory>"
fi
if [[ ! -d "${BACKUP_PATH}" ]]; then
    die "Backup directory not found: ${BACKUP_PATH}"
fi

echo ""
log_warn "This will overwrite the current Zabbix database and Grafana data with the contents of:"
log_warn "  ${BACKUP_PATH}"
read -rp "Type 'yes' to continue: " CONFIRM
if [[ "${CONFIRM}" != "yes" ]]; then
    log_info "Aborted."
    exit 0
fi

step "Stopping services"
systemctl stop zabbix-server grafana-server

if [[ -f "${BACKUP_PATH}/zabbix-db.sql.gz" ]]; then
    step "Restoring Zabbix database"
    zcat "${BACKUP_PATH}/zabbix-db.sql.gz" | mysql -uroot -p"${DB_ROOT_PASSWORD}" "${DB_NAME}"
    log_ok "Database restored."
else
    log_warn "No zabbix-db.sql.gz found in backup; skipping database restore."
fi

if [[ -f "${BACKUP_PATH}/grafana-data.tar.gz" ]]; then
    step "Restoring Grafana data directory"
    rm -rf /var/lib/grafana.restoring
    mv /var/lib/grafana /var/lib/grafana.old.$(date +%s) 2>/dev/null || true
    tar -xzf "${BACKUP_PATH}/grafana-data.tar.gz" -C /var/lib
    chown -R grafana:grafana /var/lib/grafana
    log_ok "Grafana data restored."
else
    log_warn "No grafana-data.tar.gz found in backup; skipping Grafana data restore."
fi

if [[ -d "${BACKUP_PATH}/config" ]]; then
    step "Restoring configuration files"
    [[ -f "${BACKUP_PATH}/config/grafana.ini" ]] && cp "${BACKUP_PATH}/config/grafana.ini" /etc/grafana/grafana.ini
    [[ -d "${BACKUP_PATH}/config/grafana-provisioning" ]] && cp -r "${BACKUP_PATH}/config/grafana-provisioning/." /etc/grafana/provisioning/
    [[ -f "${BACKUP_PATH}/config/zabbix_server.conf" ]] && cp "${BACKUP_PATH}/config/zabbix_server.conf" /etc/zabbix/zabbix_server.conf
    [[ -f "${BACKUP_PATH}/config/zabbix_agent2.conf" ]] && cp "${BACKUP_PATH}/config/zabbix_agent2.conf" /etc/zabbix/zabbix_agent2.conf
    [[ -f "${BACKUP_PATH}/config/zabbix-monitoring.conf" ]] && cp "${BACKUP_PATH}/config/zabbix-monitoring.conf" /etc/nginx/sites-available/zabbix-monitoring.conf
    log_ok "Configuration files restored."
fi

step "Restarting services"
systemctl start zabbix-server grafana-server
systemctl restart nginx

step "Running health check"
bash "${SCRIPT_DIR}/scripts/health_check.sh" || log_warn "Some components reported issues after restore."

log_ok "Restore completed from ${BACKUP_PATH}"
