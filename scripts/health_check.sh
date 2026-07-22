#!/bin/bash
###############################################################################
# health_check.sh
# Verifies that all components of the monitoring stack are running and
# reachable. Can be run any time after installation to diagnose issues.
###############################################################################
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

load_env

step "Checking system services"
FAILED=0
for svc in mariadb zabbix-server zabbix-agent2 grafana-server nginx snmpd; do
    if systemctl is-active --quiet "${svc}" 2>/dev/null; then
        log_ok "${svc} is running"
    else
        log_error "${svc} is NOT running"
        FAILED=1
    fi
done

step "Checking database connectivity"
if mysql -u"${DB_USER}" -p"${DB_PASSWORD}" -e "SELECT 1;" "${DB_NAME}" >/dev/null 2>&1; then
    log_ok "Database connection successful"
else
    log_error "Could not connect to database '${DB_NAME}' as '${DB_USER}'"
    FAILED=1
fi

step "Checking Zabbix server port (${ZABBIX_SERVER_PORT:-10051})"
if (echo > "/dev/tcp/127.0.0.1/${ZABBIX_SERVER_PORT:-10051}") >/dev/null 2>&1; then
    log_ok "Zabbix server port is open"
else
    log_error "Zabbix server port is not reachable"
    FAILED=1
fi

step "Checking Grafana API (port ${GRAFANA_PORT:-3000})"
if curl -fsS "http://127.0.0.1:${GRAFANA_PORT:-3000}/api/health" >/dev/null 2>&1; then
    log_ok "Grafana API responding"
else
    log_error "Grafana API not responding"
    FAILED=1
fi

step "Checking Nginx / Zabbix frontend (port ${WEB_LISTEN_PORT:-80})"
if curl -fsS -o /dev/null "http://127.0.0.1:${WEB_LISTEN_PORT:-80}${ZABBIX_URL_PATH:-/zabbix}/index.php"; then
    log_ok "Zabbix frontend reachable via Nginx"
else
    log_warn "Zabbix frontend did not respond as expected (it may still be initializing)"
fi

step "Checking SNMP daemon"
if command_exists snmpget && snmpget -v2c -c "${SNMP_DEFAULT_COMMUNITY:-public_ro_CHANGE_ME}" -t 2 localhost 1.3.6.1.2.1.1.1.0 >/dev/null 2>&1; then
    log_ok "Local SNMP daemon responding"
else
    log_warn "Local SNMP check did not respond (verify community string / snmpd status)"
fi

echo ""
if [[ "${FAILED}" -eq 0 ]]; then
    log_ok "Health check passed: all critical components are healthy."
else
    log_error "Health check found one or more failing components. Review the log above."
    exit 1
fi
