#!/bin/bash
###############################################################################
# install.sh
# Main entry point for open-monitoring-stack-grafana-zabbix.
#
# Deploys a complete, vendor-neutral monitoring platform:
#   MariaDB + Zabbix Server 7.0 LTS + Zabbix Agent 2 + Zabbix Frontend
#   + Nginx + Grafana OSS 11.3.0 + Grafana Zabbix plugin
#   + SNMP/ICMP monitoring support
#
# Usage:
#   sudo ./install.sh
#
# The script is idempotent: re-running it will skip steps already completed
# and will not overwrite an existing config/.env unless you delete it first.
###############################################################################
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/scripts/common.sh"

require_root

echo ""
echo "==============================================================="
echo "  open-monitoring-stack-grafana-zabbix - Installer"
echo "==============================================================="
echo ""

validate_supported_os

ENV_FILE="${REPO_ROOT}/config/.env"

# ---------------------------------------------------------------------------
# Step 1: Gather configuration (interactive, unless config/.env already exists)
# ---------------------------------------------------------------------------
if [[ -f "${ENV_FILE}" ]]; then
    log_warn "config/.env already exists. Reusing existing configuration."
    log_warn "Delete config/.env if you want to be prompted again (reinstall/reset)."
else
    step "Initial configuration"

    read -rp "Monitoring server hostname or FQDN [monitoring.example.local]: " INPUT_HOSTNAME
    MONITORING_HOSTNAME="${INPUT_HOSTNAME:-monitoring.example.local}"

    read -rp "System timezone (e.g. Asia/Kuala_Lumpur) [UTC]: " INPUT_TZ
    SYSTEM_TIMEZONE="${INPUT_TZ:-UTC}"

    read -rsp "Database root password (leave blank to auto-generate): " INPUT_DB_ROOT_PW
    echo ""
    DB_ROOT_PASSWORD="${INPUT_DB_ROOT_PW:-$(generate_secret 24)}"

    read -rsp "Zabbix database user password (leave blank to auto-generate): " INPUT_DB_PW
    echo ""
    DB_PASSWORD="${INPUT_DB_PW:-$(generate_secret 24)}"

    read -rsp "Grafana admin password (leave blank to auto-generate): " INPUT_GRAFANA_PW
    echo ""
    GRAFANA_ADMIN_PASSWORD="${INPUT_GRAFANA_PW:-$(generate_secret 20)}"

    read -rsp "Zabbix Admin (web UI) password (leave blank to auto-generate): " INPUT_ZBX_PW
    echo ""
    ZABBIX_ADMIN_PASSWORD="${INPUT_ZBX_PW:-$(generate_secret 20)}"

    step "Writing configuration to config/.env"
    cp "${REPO_ROOT}/config/.env.example" "${ENV_FILE}"

    # Replace values in the copied .env
    sed -i \
        -e "s#^MONITORING_HOSTNAME=.*#MONITORING_HOSTNAME=${MONITORING_HOSTNAME}#" \
        -e "s#^SYSTEM_TIMEZONE=.*#SYSTEM_TIMEZONE=${SYSTEM_TIMEZONE}#" \
        -e "s#^DB_ROOT_PASSWORD=.*#DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD}#" \
        -e "s#^DB_PASSWORD=.*#DB_PASSWORD=${DB_PASSWORD}#" \
        -e "s#^GRAFANA_ADMIN_PASSWORD=.*#GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}#" \
        -e "s#^ZABBIX_ADMIN_PASSWORD=.*#ZABBIX_ADMIN_PASSWORD=${ZABBIX_ADMIN_PASSWORD}#" \
        -e "s#^SNMP_DEFAULT_COMMUNITY=.*#SNMP_DEFAULT_COMMUNITY=$(generate_secret 12)#" \
        "${ENV_FILE}"

    chmod 600 "${ENV_FILE}"
    log_ok "Configuration saved to config/.env (permissions restricted to root)."
fi

load_env

# ---------------------------------------------------------------------------
# Step 2: Requirements check
# ---------------------------------------------------------------------------
run_once "check_requirements" bash "${SCRIPT_DIR}/scripts/check_requirements.sh"

# ---------------------------------------------------------------------------
# Step 3: Install dependencies
# ---------------------------------------------------------------------------
run_once "install_dependencies" bash "${SCRIPT_DIR}/scripts/install_dependencies.sh"

# ---------------------------------------------------------------------------
# Step 4: Install and configure database
# ---------------------------------------------------------------------------
run_once "install_database" bash "${SCRIPT_DIR}/scripts/install_database.sh"

# ---------------------------------------------------------------------------
# Step 5: Install Zabbix
# ---------------------------------------------------------------------------
run_once "install_zabbix" bash "${SCRIPT_DIR}/scripts/install_zabbix.sh"

# ---------------------------------------------------------------------------
# Step 6: Install Grafana
# ---------------------------------------------------------------------------
run_once "install_grafana" bash "${SCRIPT_DIR}/scripts/install_grafana.sh"

# ---------------------------------------------------------------------------
# Step 7: Install Grafana Zabbix plugin + provisioning
# ---------------------------------------------------------------------------
run_once "install_plugins" bash "${SCRIPT_DIR}/scripts/install_plugins.sh"

# ---------------------------------------------------------------------------
# Step 8: Configure Nginx and enable services at startup
# ---------------------------------------------------------------------------
run_once "configure_services" bash "${SCRIPT_DIR}/scripts/configure_services.sh"

# ---------------------------------------------------------------------------
# Step 9: Configure firewall
# ---------------------------------------------------------------------------
run_once "configure_firewall" bash "${SCRIPT_DIR}/scripts/configure_firewall.sh"

# ---------------------------------------------------------------------------
# Step 10: Health check
# ---------------------------------------------------------------------------
step "Running post-install health check"
bash "${SCRIPT_DIR}/scripts/health_check.sh" || log_warn "Some components reported issues. Review the output above."

# ---------------------------------------------------------------------------
# Final summary
# ---------------------------------------------------------------------------
SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
[[ -z "${SERVER_IP}" ]] && SERVER_IP="<server-ip>"

echo ""
echo "==============================================================="
echo "  Installation Complete"
echo "==============================================================="
echo ""
echo "  Grafana:          http://${SERVER_IP}:${GRAFANA_PORT}"
echo "    Username:       ${GRAFANA_ADMIN_USER}"
echo "    Password:       (see config/.env -> GRAFANA_ADMIN_PASSWORD)"
echo ""
echo "  Zabbix Frontend:  http://${SERVER_IP}${ZABBIX_URL_PATH}"
echo "    Username:       ${ZABBIX_ADMIN_USER}"
echo "    Password:       (see config/.env -> ZABBIX_ADMIN_PASSWORD)"
echo ""
echo "  Configuration:    ${ENV_FILE} (permissions 600, root only)"
echo "  Logs:             ${LOG_DIR}"
echo ""
echo "  IMPORTANT: Change default credentials after first login."
echo "  See docs/installation.md and docs/snmp-monitoring.md for next steps."
echo "==============================================================="
