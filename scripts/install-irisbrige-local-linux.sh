#!/usr/bin/env bash

set -euo pipefail

REPOSITORY="${REPOSITORY:-Irisbrige/homebrew-irisbrige}"
BINARY_NAME="${BINARY_NAME:-irisbrige-local}"
SERVICE_NAME="${SERVICE_NAME:-irisbrige-local}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
BIN_PATH="${INSTALL_DIR}/${BINARY_NAME}"
SERVICE_FILE="${SERVICE_FILE:-/etc/systemd/system/${SERVICE_NAME}.service}"
TMP_DIR=""

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

cleanup_tmp_dir() {
  if [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]]; then
    rm -rf -- "${TMP_DIR}"
  fi
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    fatal "Please run this script with sudo or as root."
  fi
}

require_linux() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    fatal "This installer only supports Linux."
  fi
}

require_command() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    fatal "Missing required command: ${cmd}"
  fi
}

detect_arch() {
  case "$(uname -m)" in
    x86_64 | amd64)
      RELEASE_ARCH="amd64"
      ;;
    aarch64 | arm64)
      RELEASE_ARCH="arm64"
      ;;
    *)
      fatal "Unsupported architecture: $(uname -m)"
      ;;
  esac
}

detect_service_user() {
  if [[ -n "${SERVICE_USER:-}" ]]; then
    :
  elif [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    SERVICE_USER="${SUDO_USER}"
  else
    SERVICE_USER="root"
  fi

  if ! id "${SERVICE_USER}" >/dev/null 2>&1; then
    fatal "SERVICE_USER does not exist: ${SERVICE_USER}"
  fi

  SERVICE_GROUP="$(id -gn "${SERVICE_USER}")"
  SERVICE_HOME="$(getent passwd "${SERVICE_USER}" | awk -F: '{print $6}')"

  if [[ -z "${SERVICE_HOME}" ]]; then
    fatal "Could not determine home directory for ${SERVICE_USER}"
  fi

  if [[ ! -d "${SERVICE_HOME}" ]]; then
    fatal "Home directory does not exist for ${SERVICE_USER}: ${SERVICE_HOME}"
  fi
}

build_service_path() {
  local base_path user_path

  base_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  user_path="${SERVICE_HOME}/.local/bin:${SERVICE_HOME}/bin"
  SERVICE_PATH="${SERVICE_PATH:-${base_path}:${user_path}}"
}

fetch_latest_release_metadata() {
  local latest_url

  latest_url="$(
    curl --fail --silent --show-error --location --retry 3 \
      --output /dev/null \
      --write-out '%{url_effective}' \
      "https://github.com/${REPOSITORY}/releases/latest"
  )"

  RELEASE_TAG="${latest_url##*/}"
  if [[ -z "${RELEASE_TAG}" || "${RELEASE_TAG}" == "latest" ]]; then
    fatal "Could not resolve the latest release tag for ${REPOSITORY}"
  fi
}

resolve_download_url() {
  local release_version

  release_version="${RELEASE_TAG#v}"
  DOWNLOAD_URL="https://github.com/${REPOSITORY}/releases/download/${RELEASE_TAG}/${BINARY_NAME}_${release_version}_linux_${RELEASE_ARCH}.tar.gz"

  if [[ -z "${DOWNLOAD_URL}" ]]; then
    fatal "Could not find a Linux ${RELEASE_ARCH} release asset in ${REPOSITORY} latest release."
  fi
}

download_and_install_binary() {
  local tmp_dir archive_path extracted_path

  tmp_dir="$(mktemp -d)"
  TMP_DIR="${tmp_dir}"
  trap cleanup_tmp_dir EXIT

  archive_path="${tmp_dir}/${BINARY_NAME}.tar.gz"

  info "Downloading ${BINARY_NAME} ${RELEASE_TAG} for ${RELEASE_ARCH}"
  curl --fail --silent --show-error --location --retry 3 \
    --output "${archive_path}" \
    "${DOWNLOAD_URL}"

  if tar --help 2>&1 | grep -q -- '--warning'; then
    tar --warning=no-unknown-keyword -xzf "${archive_path}" -C "${tmp_dir}"
  else
    tar -xzf "${archive_path}" -C "${tmp_dir}"
  fi

  extracted_path="$(find "${tmp_dir}" -maxdepth 3 -type f -name "${BINARY_NAME}" | head -n 1 || true)"
  if [[ -z "${extracted_path}" ]]; then
    fatal "Archive did not contain ${BINARY_NAME}"
  fi

  install -d "${INSTALL_DIR}"
  install -m 0755 "${extracted_path}" "${BIN_PATH}"
  cleanup_tmp_dir
  TMP_DIR=""
  trap - EXIT
}

write_systemd_service() {
  cat >"${SERVICE_FILE}" <<EOF
[Unit]
Description=irisbrige-local service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_GROUP}
WorkingDirectory=${SERVICE_HOME}
Environment=HOME=${SERVICE_HOME}
Environment=PATH=${SERVICE_PATH}
ExecStart=${BIN_PATH} server
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

  chmod 0644 "${SERVICE_FILE}"
}

enable_and_start_service() {
  systemctl daemon-reload
  systemctl enable "${SERVICE_NAME}" >/dev/null

  if systemctl is-active --quiet "${SERVICE_NAME}"; then
    systemctl restart "${SERVICE_NAME}"
  else
    systemctl start "${SERVICE_NAME}"
  fi
}

print_summary() {
  cat <<EOF

Installed ${BINARY_NAME} to: ${BIN_PATH}
Latest release tag: ${RELEASE_TAG}
Systemd service: ${SERVICE_FILE}
Service user: ${SERVICE_USER}

Useful commands:
  systemctl status ${SERVICE_NAME} --no-pager
  journalctl -u ${SERVICE_NAME} -f
EOF
}

main() {
  require_linux
  require_root
  require_command curl
  require_command tar
  require_command systemctl
  require_command install
  require_command getent
  require_command find
  require_command awk
  require_command grep

  detect_arch
  detect_service_user
  build_service_path
  fetch_latest_release_metadata
  resolve_download_url
  download_and_install_binary
  write_systemd_service
  enable_and_start_service
  print_summary
}

main "$@"
