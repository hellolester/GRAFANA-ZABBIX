#!/bin/bash
###############################################################################
# common.sh
# Shared helper functions sourced by every script in this repository.
# Provides logging, error handling, OS detection, and small utilities.
###############################################################################

# Guard against being executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "common.sh is a library and must be sourced, not executed directly." >&2
    exit 1
fi

# Resolve repository root regardless of caller's working directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${REPO_ROOT}/logs"
LOG_FILE="${LOG_DIR}/install-$(date +%Y%m%d).log"
mkdir -p "${LOG_DIR}"

# Colors (fall back gracefully if terminal doesn't support them)
if [[ -t 1 ]]; then
    COLOR_RED="\033[0;31m"
    COLOR_GREEN="\033[0;32m"
    COLOR_YELLOW="\033[0;33m"
    COLOR_BLUE="\033[0;34m"
    COLOR_RESET="\033[0m"
else
    COLOR_RED=""; COLOR_GREEN=""; COLOR_YELLOW=""; COLOR_BLUE=""; COLOR_RESET=""
fi

log_info()  { echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET}  $*" | tee -a "${LOG_FILE}"; }
log_ok()    { echo -e "${COLOR_GREEN}[OK]${COLOR_RESET}    $*" | tee -a "${LOG_FILE}"; }
log_warn()  { echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET}  $*" | tee -a "${LOG_FILE}"; }
log_error() { echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" | tee -a "${LOG_FILE}" >&2; }

step() {
    echo "" | tee -a "${LOG_FILE}"
    echo -e "${COLOR_BLUE}==>${COLOR_RESET} $*" | tee -a "${LOG_FILE}"
}

die() {
    log_error "$*"
    exit 1
}

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        die "This script must be run as root (use sudo)."
    fi
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect OS ID and VERSION_ID from /etc/os-release
detect_os() {
    if [[ ! -f /etc/os-release ]]; then
        die "/etc/os-release not found. Unsupported operating system."
    fi
    # shellcheck disable=SC1091
    source /etc/os-release
    OS_ID="${ID}"
    OS_VERSION="${VERSION_ID}"
    export OS_ID OS_VERSION
}

# Verify OS is a supported target; exits with error otherwise
validate_supported_os() {
    detect_os
    if [[ "${OS_ID}" != "ubuntu" ]]; then
        die "Unsupported OS '${OS_ID}'. This project supports Ubuntu 22.04 and 24.04 LTS only."
    fi
    case "${OS_VERSION}" in
        22.04|24.04)
            log_ok "Detected supported OS: Ubuntu ${OS_VERSION}"
            ;;
        *)
            die "Unsupported Ubuntu version '${OS_VERSION}'. Supported: 22.04, 24.04."
            ;;
    esac
}

# Load environment file, exporting all variables
load_env() {
    local env_file="${1:-${REPO_ROOT}/config/.env}"
    if [[ ! -f "${env_file}" ]]; then
        die "Environment file not found at ${env_file}. Run install.sh first."
    fi
    set -a
    # shellcheck disable=SC1090
    source "${env_file}"
    set +a
}

# Generate a random alphanumeric secret of a given length (default 24)
generate_secret() {
    local length="${1:-24}"
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "${length}"
}

# Idempotency helper: run a command only if a marker file doesn't yet exist
run_once() {
    local marker_name="$1"
    shift
    local marker_dir="${REPO_ROOT}/.state"
    mkdir -p "${marker_dir}"
    local marker_file="${marker_dir}/${marker_name}.done"
    if [[ -f "${marker_file}" ]]; then
        log_warn "Step '${marker_name}' already completed previously. Skipping (idempotent)."
        return 0
    fi
    "$@"
    local rc=$?
    if [[ ${rc} -eq 0 ]]; then
        touch "${marker_file}"
    fi
    return ${rc}
}

wait_for_apt_lock() {
    local tries=0
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        tries=$((tries + 1))
        if [[ ${tries} -gt 60 ]]; then
            die "Timed out waiting for apt/dpkg lock to be released."
        fi
        log_warn "Waiting for other apt/dpkg process to finish..."
        sleep 5
    done
}

apt_install() {
    wait_for_apt_lock
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" 2>&1 | tee -a "${LOG_FILE}"
    return "${PIPESTATUS[0]}"
}

port_in_use() {
    local port="$1"
    ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":${port}$"
}
