#!/bin/bash
###############################################################################
# install_zabbix.sh
# Installs Zabbix Server 7.0 LTS, Frontend, Agent 2, and SQL scripts from
# the official Zabbix repository. Configures zabbix_server.conf and imports
# the database schema if it wasn't already imported by install_database.sh.
###############################################################################
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

require_root
load_env
detect_os

ZBX_VER="${ZABBIX_VERSION:-7.0}"

step "Adding official Zabbix ${ZBX_VER} repository"
ZBX_REPO_DEB="zabbix-release_latest_${ZBX_VER}+ubuntu${OS_VERSION}_all.deb"
ZBX_REPO_URL="https://repo.zabbix.com/zabbix/${ZBX_VER}/ubuntu/pool/main/z/zabbix-release/${ZBX_REPO_DEB}"

TMP_DEB="/tmp/${ZBX_REPO_DEB}"
if ! dpkg -l | grep -q zabbix-release; then
    wget -q "${ZBX_REPO_URL}" -O "${TMP_DEB}" || die "Failed to download Zabbix repository package from ${ZBX_REPO_URL}"
    dpkg -i "${TMP_DEB}"
    wait_for_apt_lock
    apt-get update -y | tee -a "${LOG_FILE}"
else
    log_warn "Zabbix repository already registered. Skipping (idempotent)."
fi

step "Installing Zabbix server, frontend, agent2, and SQL scripts"
apt_install \
    zabbix-server-mysql \
    zabbix-frontend-php \
    zabbix-apache-conf \
    zabbix-sql-scripts \
    zabbix-agent2 \
    zabbix-agent2-plugin-mongodb \
    zabbix-agent2-plugin-postgresql

# We use Nginx, not Apache, so disable the Apache config package if it pulled Apache in
if systemctl list-unit-files | grep -q '^apache2.service'; then
    systemctl disable --now apache2 2>/dev/null || true
    log_warn "Apache2 was installed as a dependency and has been disabled (Nginx is used instead)."
fi

step "Importing Zabbix database schema (if needed)"
TABLE_EXISTS=$(mysql -uroot -p"${DB_ROOT_PASSWORD}" -N -B -e \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}' AND table_name='dbversion';" 2>/dev/null || echo 0)

if [[ "${TABLE_EXISTS}" -eq 0 ]]; then
    SCHEMA_PATH="/usr/share/zabbix-sql-scripts/mysql/server.sql.gz"
    [[ -f "${SCHEMA_PATH}" ]] || SCHEMA_PATH="/usr/share/doc/zabbix-sql-scripts/mysql/server.sql.gz"
    [[ -f "${SCHEMA_PATH}" ]] || die "Could not locate Zabbix SQL schema file after package installation."
    zcat "${SCHEMA_PATH}" | mysql -uroot -p"${DB_ROOT_PASSWORD}" "${DB_NAME}"
    log_ok "Zabbix schema imported."
else
    log_warn "Zabbix schema already present. Skipping import (idempotent)."
fi

step "Configuring zabbix_server.conf"
ZBX_CONF="/etc/zabbix/zabbix_server.conf"
cp "${REPO_ROOT}/config/zabbix_server.conf" "${ZBX_CONF}.template"

sed -e "s/{{DB_HOST}}/${DB_HOST}/g" \
    -e "s/{{DB_NAME}}/${DB_NAME}/g" \
    -e "s/{{DB_USER}}/${DB_USER}/g" \
    -e "s/{{DB_PASSWORD}}/${DB_PASSWORD}/g" \
    -e "s/{{DB_PORT}}/${DB_PORT}/g" \
    "${ZBX_CONF}.template" > "${ZBX_CONF}"
rm -f "${ZBX_CONF}.template"
chown zabbix:zabbix "${ZBX_CONF}"
chmod 640 "${ZBX_CONF}"
log_ok "zabbix_server.conf configured."

step "Configuring PHP frontend timezone"
PHP_FPM_CONF=$(find /etc/zabbix -name "apache.conf" 2>/dev/null | head -n1)
if [[ -n "${PHP_FPM_CONF}" ]] && [[ -n "${SYSTEM_TIMEZONE:-}" ]]; then
    sed -i "s#php_value\[date.timezone\].*#php_value[date.timezone] ${SYSTEM_TIMEZONE}#" "${PHP_FPM_CONF}" || true
fi

# Set timezone for PHP-FPM pool used by Nginx
PHP_INI=$(find /etc/php -name "php.ini" -path "*fpm*" 2>/dev/null | head -n1)
if [[ -n "${PHP_INI}" ]] && [[ -n "${SYSTEM_TIMEZONE:-}" ]]; then
    sed -i "s#^;\?date.timezone.*#date.timezone = ${SYSTEM_TIMEZONE}#" "${PHP_INI}"
    log_ok "PHP timezone set to ${SYSTEM_TIMEZONE}."
fi

step "Configuring Zabbix Agent 2"
sed -i "s/^Server=.*/Server=127.0.0.1/" /etc/zabbix/zabbix_agent2.conf
sed -i "s/^ServerActive=.*/ServerActive=127.0.0.1/" /etc/zabbix/zabbix_agent2.conf
sed -i "s/^Hostname=.*/Hostname=${MONITORING_HOSTNAME}/" /etc/zabbix/zabbix_agent2.conf

step "Enabling and starting Zabbix services"
systemctl restart zabbix-server zabbix-agent2
systemctl enable zabbix-server zabbix-agent2 php*-fpm 2>/dev/null || true

log_ok "Zabbix installation completed."
