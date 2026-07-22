#!/bin/bash
###############################################################################
# install_database.sh
# Installs and configures MariaDB, creates the Zabbix database, user, and
# imports the initial schema. Idempotent: safe to re-run.
###############################################################################
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

require_root
load_env

step "Installing MariaDB server"
apt_install mariadb-server mariadb-client

systemctl enable mariadb
systemctl start mariadb

step "Applying database hardening and root password"
# Only set the root password if it hasn't already been secured
if mysql -uroot -e "SELECT 1;" >/dev/null 2>&1; then
    mysql -uroot <<-SQL
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
        DELETE FROM mysql.user WHERE User='';
        DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost','127.0.0.1','::1');
        DROP DATABASE IF EXISTS test;
        FLUSH PRIVILEGES;
SQL
    log_ok "MariaDB root account secured."
else
    log_warn "MariaDB root already password-protected; skipping hardening step."
fi

step "Creating Zabbix database and user"
mysql -uroot -p"${DB_ROOT_PASSWORD}" <<-SQL
    CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
    CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
    GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
    SET GLOBAL log_bin_trust_function_creators = 1;
    FLUSH PRIVILEGES;
SQL
log_ok "Database '${DB_NAME}' and user '${DB_USER}' ready."

# Persist log_bin_trust_function_creators across restarts (required by Zabbix schema import)
CNF_INCLUDE_DIR="/etc/mysql/mariadb.conf.d"
if [[ -d "${CNF_INCLUDE_DIR}" ]] && ! grep -rq "log_bin_trust_function_creators" "${CNF_INCLUDE_DIR}" 2>/dev/null; then
    cat >> "${CNF_INCLUDE_DIR}/60-zabbix.cnf" <<-EOF
[mysqld]
log_bin_trust_function_creators = 1
EOF
    systemctl restart mariadb
    log_ok "Persisted log_bin_trust_function_creators setting."
fi

step "Importing Zabbix schema (if not already imported)"
SCHEMA_MARKER_TABLE="dbversion"
TABLE_EXISTS=$(mysql -uroot -p"${DB_ROOT_PASSWORD}" -N -B -e \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}' AND table_name='${SCHEMA_MARKER_TABLE}';")

if [[ "${TABLE_EXISTS}" -eq 0 ]]; then
    if [[ -f /usr/share/zabbix/sql-scripts/mysql/server.sql.gz ]]; then
        SCHEMA_PATH="/usr/share/zabbix/sql-scripts/mysql/server.sql.gz"
    elif [[ -f /usr/share/doc/zabbix-sql-scripts/mysql/server.sql.gz ]]; then
        SCHEMA_PATH="/usr/share/doc/zabbix-sql-scripts/mysql/server.sql.gz"
    else
        SCHEMA_PATH=""
    fi

    if [[ -n "${SCHEMA_PATH}" ]]; then
        zcat "${SCHEMA_PATH}" | mysql -uroot -p"${DB_ROOT_PASSWORD}" "${DB_NAME}"
        log_ok "Zabbix schema imported from ${SCHEMA_PATH}."
    else
        log_warn "Zabbix schema file not found yet. It will be imported by install_zabbix.sh after the zabbix-sql-scripts package is installed."
    fi
else
    log_warn "Zabbix schema already present in database. Skipping import (idempotent)."
fi

log_ok "Database installation completed."
