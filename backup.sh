#!/bin/bash
###############################################################################
# backup.sh
# Creates a timestamped backup of the Zabbix database, Grafana database/data,
# and all configuration files. Backups are stored under ./backups/.
#
# Usage:
#   sudo ./backup.sh                # standard backup
#   sudo ./backup.sh --pre-update    # backup tagged as a pre-update snapshot
###############################################################################
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/scripts/common.sh"

require_root
load_env

TAG="manual"
if [[ "${1:-}" == "--pre-update" ]]; then
    TAG="pre-update"
fi

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="${REPO_ROOT}/backups/${TIMESTAMP}-${TAG}"
mkdir -p "${BACKUP_DIR}"

step "Backing up Zabbix database"
mysqldump -uroot -p"${DB_ROOT_PASSWORD}" --single-transaction --quick --routines --triggers \
    "${DB_NAME}" | gzip > "${BACKUP_DIR}/zabbix-db.sql.gz"
log_ok "Database backed up to ${BACKUP_DIR}/zabbix-db.sql.gz"

step "Backing up Grafana data directory"
if [[ -d /var/lib/grafana ]]; then
    tar -czf "${BACKUP_DIR}/grafana-data.tar.gz" -C /var/lib grafana
    log_ok "Grafana data backed up to ${BACKUP_DIR}/grafana-data.tar.gz"
fi

step "Backing up Grafana and Zabbix configuration files"
mkdir -p "${BACKUP_DIR}/config"
[[ -f /etc/grafana/grafana.ini ]] && cp /etc/grafana/grafana.ini "${BACKUP_DIR}/config/"
[[ -d /etc/grafana/provisioning ]] && cp -r /etc/grafana/provisioning "${BACKUP_DIR}/config/grafana-provisioning"
[[ -f /etc/zabbix/zabbix_server.conf ]] && cp /etc/zabbix/zabbix_server.conf "${BACKUP_DIR}/config/"
[[ -f /etc/zabbix/zabbix_agent2.conf ]] && cp /etc/zabbix/zabbix_agent2.conf "${BACKUP_DIR}/config/"
[[ -f /etc/nginx/sites-available/zabbix-monitoring.conf ]] && cp /etc/nginx/sites-available/zabbix-monitoring.conf "${BACKUP_DIR}/config/"

step "Backing up project .env (encrypted copy recommended for long-term storage)"
[[ -f "${REPO_ROOT}/config/.env" ]] && cp "${REPO_ROOT}/config/.env" "${BACKUP_DIR}/config/.env.bak"

chmod -R 600 "${BACKUP_DIR}"/config/* 2>/dev/null || true

step "Writing backup manifest"
cat > "${BACKUP_DIR}/manifest.txt" <<EOF
Backup created: $(date)
Tag: ${TAG}
Hostname: ${MONITORING_HOSTNAME}
Zabbix version: ${ZABBIX_VERSION}
Grafana version: ${GRAFANA_VERSION}
Contents:
  - zabbix-db.sql.gz     : full MariaDB dump of the Zabbix database
  - grafana-data.tar.gz  : Grafana's /var/lib/grafana directory (sqlite db, plugins, dashboards)
  - config/              : Grafana, Zabbix, Nginx configuration files and .env backup
EOF

log_ok "Backup completed: ${BACKUP_DIR}"
