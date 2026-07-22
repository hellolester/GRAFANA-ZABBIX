#!/bin/bash
###############################################################################
# check_requirements.sh
# Validates that the host meets minimum requirements before installation:
# supported OS, CPU, RAM, disk space, network connectivity, and root access.
###############################################################################
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/common.sh"

step "Checking system requirements"

require_root
validate_supported_os

# --- CPU ---
CPU_CORES=$(nproc)
if [[ "${CPU_CORES}" -lt 2 ]]; then
    log_warn "Only ${CPU_CORES} CPU core(s) detected. Recommended minimum: 2 cores."
else
    log_ok "CPU cores: ${CPU_CORES}"
fi

# --- RAM ---
TOTAL_RAM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
if [[ "${TOTAL_RAM_MB}" -lt 2048 ]]; then
    log_warn "Only ${TOTAL_RAM_MB} MB RAM detected. Recommended minimum: 4096 MB."
else
    log_ok "RAM: ${TOTAL_RAM_MB} MB"
fi

# --- Disk space (root filesystem) ---
AVAILABLE_DISK_GB=$(df -BG / | awk 'NR==2 {gsub("G","",$4); print $4}')
if [[ "${AVAILABLE_DISK_GB}" -lt 10 ]]; then
    die "Insufficient disk space. At least 10 GB free is required on / (found ${AVAILABLE_DISK_GB} GB)."
else
    log_ok "Available disk space: ${AVAILABLE_DISK_GB} GB"
fi

# --- Network connectivity ---
if command_exists curl; then
    if curl -fsSL --max-time 5 https://repo.zabbix.com >/dev/null 2>&1 \
        || curl -fsSL --max-time 5 https://packages.grafana.com >/dev/null 2>&1; then
        log_ok "Internet connectivity confirmed."
    else
        log_warn "Could not confirm internet connectivity to package repositories. Continuing, but installation may fail."
    fi
else
    log_warn "curl not yet installed; connectivity check will run again after dependency installation."
fi

# --- Required ports free ---
for p in 80 3000 3306 10050 10051; do
    if port_in_use "${p}"; then
        log_warn "Port ${p} already appears to be in use. This may conflict with the monitoring stack."
    else
        log_ok "Port ${p} is free."
    fi
done

# --- systemd availability ---
if ! command_exists systemctl; then
    die "systemd (systemctl) is required and was not found."
fi
log_ok "systemd detected."

log_ok "All requirement checks completed."
