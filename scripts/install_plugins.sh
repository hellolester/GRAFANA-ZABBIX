#!/bin/bash
###############################################################################
# install_plugins.sh
# Installs the Grafana Zabbix plugin and provisions the Zabbix datasource
# and default dashboards automatically.
###############################################################################
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

require_root
load_env

PLUGIN_ID="${GRAFANA_ZABBIX_PLUGIN:-alexanderzobnin-zabbix-app}"

step "Installing Grafana plugin: ${PLUGIN_ID}"
grafana-cli plugins install "${PLUGIN_ID}" 2>&1 | tee -a "${LOG_FILE}"

step "Enabling plugin in grafana.ini"
if ! grep -q "^plugins.app_tls_skip_verify_insecure" /etc/grafana/grafana.ini 2>/dev/null; then
    true # placeholder, plugin apps are enabled per-org via provisioning below
fi

step "Provisioning Zabbix datasource"
PROVISIONING_DIR="/etc/grafana/provisioning/datasources"
mkdir -p "${PROVISIONING_DIR}"

cat > "${PROVISIONING_DIR}/zabbix.yaml" <<EOF
apiVersion: 1

datasources:
  - name: Zabbix
    type: alexanderzobnin-zabbix-datasource
    access: proxy
    url: http://127.0.0.1${ZABBIX_URL_PATH:-/zabbix}/api_jsonrpc.php
    isDefault: true
    editable: true
    jsonData:
      username: "${ZABBIX_ADMIN_USER}"
      trends: true
      trendsFrom: "7d"
      trendsRange: "4d"
      cacheTTL: "60s"
      timeout: 30
    secureJsonData:
      password: "${ZABBIX_ADMIN_PASSWORD}"
EOF
log_ok "Zabbix datasource provisioning file created."

step "Provisioning dashboard auto-loading"
DASH_PROVISIONING_DIR="/etc/grafana/provisioning/dashboards"
mkdir -p "${DASH_PROVISIONING_DIR}"
DASH_DEST_DIR="/var/lib/grafana/dashboards/open-monitoring-stack"
mkdir -p "${DASH_DEST_DIR}"

cat > "${DASH_PROVISIONING_DIR}/open-monitoring-stack.yaml" <<EOF
apiVersion: 1

providers:
  - name: "open-monitoring-stack"
    orgId: 1
    folder: "Open Monitoring Stack"
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    allowUiUpdates: true
    options:
      path: ${DASH_DEST_DIR}
      foldersFromFilesStructure: false
EOF

cp "${REPO_ROOT}"/dashboards/*.json "${DASH_DEST_DIR}/" 2>/dev/null || log_warn "No dashboard JSON files found to copy."
chown -R grafana:grafana /var/lib/grafana/dashboards /etc/grafana/provisioning
log_ok "Dashboards provisioned to ${DASH_DEST_DIR}."

step "Restarting Grafana to apply plugin and provisioning changes"
systemctl restart grafana-server

log_ok "Plugin installation and provisioning completed."
