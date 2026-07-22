#!/bin/bash
###############################################################################
# configure_services.sh
# Installs and configures Nginx as the front-end web server for the Zabbix
# frontend, enables all services to start at boot, and disables unnecessary
# services for a leaner security footprint.
###############################################################################
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

require_root
load_env

step "Installing Nginx"
apt_install nginx

step "Deploying Nginx site configuration"
NGINX_SITE="/etc/nginx/sites-available/zabbix-monitoring.conf"
cp "${REPO_ROOT}/config/nginx.conf" "${NGINX_SITE}"

PHP_FPM_SOCK=$(find /run/php -name "*.sock" 2>/dev/null | head -n1)
if [[ -z "${PHP_FPM_SOCK}" ]]; then
    PHP_FPM_SOCK="/run/php/php-fpm.sock"
fi

sed -e "s#{{WEB_LISTEN_PORT}}#${WEB_LISTEN_PORT:-80}#g" \
    -e "s#{{MONITORING_HOSTNAME}}#${MONITORING_HOSTNAME}#g" \
    -e "s#{{PHP_FPM_SOCK}}#${PHP_FPM_SOCK}#g" \
    -e "s#{{ZABBIX_URL_PATH}}#${ZABBIX_URL_PATH:-/zabbix}#g" \
    -i "${NGINX_SITE}"

ln -sf "${NGINX_SITE}" /etc/nginx/sites-enabled/zabbix-monitoring.conf
rm -f /etc/nginx/sites-enabled/default

step "Testing Nginx configuration"
nginx -t

step "Restarting Nginx"
systemctl enable nginx
systemctl restart nginx

step "Disabling unnecessary / insecure services"
for svc in apache2 sendmail postfix; do
    if systemctl list-unit-files 2>/dev/null | grep -q "^${svc}.service"; then
        systemctl disable --now "${svc}" 2>/dev/null || true
        log_warn "Disabled unnecessary service: ${svc}"
    fi
done

step "Enabling all core services at startup"
for svc in mariadb zabbix-server zabbix-agent2 grafana-server nginx snmpd; do
    if systemctl list-unit-files 2>/dev/null | grep -q "^${svc}.service"; then
        systemctl enable "${svc}" 2>/dev/null || true
    fi
done

step "Configuring SNMP daemon (local agent, read-only)"
SNMPD_CONF="/etc/snmp/snmpd.conf"
if [[ -f "${SNMPD_CONF}" ]] && ! grep -q "^# managed by open-monitoring-stack" "${SNMPD_CONF}"; then
    cp "${SNMPD_CONF}" "${SNMPD_CONF}.bak.$(date +%s)"
    cat > "${SNMPD_CONF}" <<EOF
# managed by open-monitoring-stack
agentAddress udp:161
rocommunity ${SNMP_DEFAULT_COMMUNITY:-public_ro_CHANGE_ME} default -V systemonly
sysLocation "Set your location"
sysContact "Set your contact"
EOF
    systemctl restart snmpd
    systemctl enable snmpd
    log_ok "snmpd configured with a restricted read-only community string."
fi

log_ok "Service configuration completed."
