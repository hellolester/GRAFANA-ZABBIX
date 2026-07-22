#!/bin/bash
###############################################################################
# install_grafana.sh
# Installs Grafana OSS at the pinned version from the official APT repository,
# applies grafana.ini, and sets the initial admin password.
###############################################################################
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

require_root
load_env

GRAFANA_VER="${GRAFANA_VERSION:-11.3.0}"

step "Adding official Grafana APT repository"
mkdir -p /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/grafana.gpg ]]; then
    wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor > /etc/apt/keyrings/grafana.gpg
fi
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
    > /etc/apt/sources.list.d/grafana.list

wait_for_apt_lock
apt-get update -y | tee -a "${LOG_FILE}"

step "Installing Grafana OSS ${GRAFANA_VER}"
GRAFANA_PKG="grafana=${GRAFANA_VER}"
if ! apt_install "${GRAFANA_PKG}"; then
    log_warn "Pinned version ${GRAFANA_VER} not available in repository. Falling back to latest available grafana package."
    apt_install grafana
fi

step "Applying grafana.ini configuration"
install -m 640 -o root -g grafana "${REPO_ROOT}/config/grafana.ini" /etc/grafana/grafana.ini

# Inject dynamic values
sed -i "s/{{GRAFANA_PORT}}/${GRAFANA_PORT}/g" /etc/grafana/grafana.ini
sed -i "s#{{MONITORING_HOSTNAME}}#${MONITORING_HOSTNAME}#g" /etc/grafana/grafana.ini

step "Enabling and starting Grafana"
systemctl enable grafana-server
systemctl restart grafana-server

step "Waiting for Grafana API to become available"
TRIES=0
until curl -fsS "http://127.0.0.1:${GRAFANA_PORT}/api/health" >/dev/null 2>&1; do
    TRIES=$((TRIES + 1))
    if [[ ${TRIES} -gt 30 ]]; then
        die "Grafana did not become available on port ${GRAFANA_PORT} in time."
    fi
    sleep 2
done
log_ok "Grafana is up on port ${GRAFANA_PORT}."

step "Setting Grafana admin password"
grafana-cli --homepath /usr/share/grafana admin reset-admin-password "${GRAFANA_ADMIN_PASSWORD}" \
    2>&1 | tee -a "${LOG_FILE}" || log_warn "Could not reset admin password via grafana-cli; set it manually on first login."

log_ok "Grafana installation completed."
