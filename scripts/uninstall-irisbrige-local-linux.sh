#!/usr/bin/env bash

set -euo pipefail

BINARY_NAME="${BINARY_NAME:-irisbrige-local}"
SERVICE_NAME="${SERVICE_NAME:-irisbrige-local}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
BIN_PATH="${INSTALL_DIR}/${BINARY_NAME}"
SERVICE_FILE="${SERVICE_FILE:-/etc/systemd/system/${SERVICE_NAME}.service}"

log() {
  printf '[%s] %s\n' "$1" "$2"
}

info() {
  log INFO "$1"
}

fatal() {
  log ERROR "$1" >&2
  exit 1
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    fatal "Please run this script with sudo or as root."
  fi
}

require_linux() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    fatal "This uninstaller only supports Linux."
  fi
}

require_command() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    fatal "Missing required command: ${cmd}"
  fi
}

stop_service_if_present() {
  if systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
    info "Stopping ${SERVICE_NAME}"
    systemctl stop "${SERVICE_NAME}"
  fi
}

disable_service_if_present() {
  if systemctl list-unit-files --type=service --all 2>/dev/null | awk '{print $1}' | grep -Fxq "${SERVICE_NAME}.service"; then
    info "Disabling ${SERVICE_NAME}"
    systemctl disable "${SERVICE_NAME}" >/dev/null 2>&1 || true
  fi
}

remove_service_file_if_present() {
  if [[ -f "${SERVICE_FILE}" ]]; then
    info "Removing systemd unit file: ${SERVICE_FILE}"
    rm -f "${SERVICE_FILE}"
  else
    info "Systemd unit file not present: ${SERVICE_FILE}"
  fi
}

remove_binary_if_present() {
  if [[ -f "${BIN_PATH}" ]]; then
    info "Removing binary: ${BIN_PATH}"
    rm -f "${BIN_PATH}"
  else
    info "Binary not present: ${BIN_PATH}"
  fi
}

reload_systemd_state() {
  info "Reloading systemd state"
  systemctl daemon-reload
  systemctl reset-failed "${SERVICE_NAME}" >/dev/null 2>&1 || true
}

print_summary() {
  cat <<EOF

Removed systemd service: ${SERVICE_NAME}
Removed unit file: ${SERVICE_FILE}
Removed binary: ${BIN_PATH}

Useful commands:
  systemctl status ${SERVICE_NAME} --no-pager
EOF
}

main() {
  require_linux
  require_root
  require_command systemctl
  require_command rm
  require_command awk
  require_command grep

  stop_service_if_present
  disable_service_if_present
  remove_service_file_if_present
  remove_binary_if_present
  reload_systemd_state
  print_summary
}

main "$@"
