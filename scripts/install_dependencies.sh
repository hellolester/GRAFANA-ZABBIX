#!/bin/bash
###############################################################################
# install_dependencies.sh
# Installs OS-level dependencies required by every component of the stack.
###############################################################################
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

require_root
validate_supported_os

step "Updating package index"
wait_for_apt_lock
apt-get update -y | tee -a "${LOG_FILE}"

step "Upgrading existing packages (safe upgrade only)"
wait_for_apt_lock
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --with-new-pkgs | tee -a "${LOG_FILE}"

step "Installing base dependencies"
apt_install \
    curl \
    wget \
    gnupg2 \
    ca-certificates \
    software-properties-common \
    apt-transport-https \
    lsb-release \
    net-tools \
    ufw \
    unzip \
    tar \
    jq \
    cron \
    snmp \
    snmpd \
    fping \
    logrotate

step "Setting system timezone"
if [[ -n "${SYSTEM_TIMEZONE:-}" ]]; then
    timedatectl set-timezone "${SYSTEM_TIMEZONE}" || log_warn "Could not set timezone to ${SYSTEM_TIMEZONE}"
    log_ok "Timezone set to ${SYSTEM_TIMEZONE}"
else
    log_warn "SYSTEM_TIMEZONE not set; leaving system timezone unchanged."
fi

log_ok "Dependency installation completed."
