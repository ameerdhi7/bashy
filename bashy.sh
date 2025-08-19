#!/usr/bin/env bash

# Bashy: simple dev service manager using PM2 with local domain support
# - Syncs your project's .env from .env.example and injects PORT/HOST
# - Keeps your dev server running with PM2 (auto restart on crash)
# - Registers/unregisters a local domain in /etc/hosts (requires sudo)
# - Adds the embedded bashy directory to your project's .gitignore
# - Stores config in .bashy.env at project root

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}"

# Defaults (can be overridden by .env)
DEFAULT_NAME="$(basename "${PROJECT_DIR}" | tr '[:space:]' '-' | tr -cd '[:alnum:]-_.' | tr '[:upper:]' '[:lower:]')"
DEFAULT_PORT="5173"
DEFAULT_DOMAIN="${DEFAULT_NAME}.local"
DEFAULT_WORKDIR="${PROJECT_DIR}"

# If package.json exists, prefer an npm dev command; otherwise fall back to python http.server
if [[ -f "${PROJECT_DIR}/package.json" ]]; then
  DEFAULT_COMMAND="npm run dev -- --host 0.0.0.0 --port ${DEFAULT_PORT}"
else
  DEFAULT_COMMAND="python3 -m http.server ${DEFAULT_PORT} --bind 127.0.0.1"
fi

# Loaded config vars (with defaults)
BASHY_NAME="${DEFAULT_NAME}"
BASHY_PORT="${DEFAULT_PORT}"
BASHY_DOMAIN="${DEFAULT_DOMAIN}"
BASHY_WORKDIR="${DEFAULT_WORKDIR}"
BASHY_COMMAND="${DEFAULT_COMMAND}"
BASHY_ENV_EXTRA="" # optional K=V,K=V pairs (comma-separated)

print_info() { printf "[bashy] %s\n" "$*"; }
print_err() { printf "[bashy] ERROR: %s\n" "$*" 1>&2; }

usage() {
  cat <<'EOF'
Bashy - automate front-end dev serving with local domain and PM2 keep-alive

Usage:
  ./bashy.sh up                  # spin up the project (pm2 and local domain from .env)
  ./bashy.sh start|stop|restart      # control the PM2 process
  ./bashy.sh status                  # show PM2 status
  ./bashy.sh logs [--follow]         # show PM2 logs (tail -f with --follow)
  ./bashy.sh delete                  # delete process from PM2
  ./bashy.sh save                    # pm2 save (persist process list)
  ./bashy.sh register-domain [IP]    # add DOMAIN -> IP (default 127.0.0.1) in /etc/hosts (sudo)
  ./bashy.sh unregister-domain       # remove DOMAIN entry from /etc/hosts (sudo)
  ./bashy.sh help

Notes:
  - Requires pm2 (npm i -g pm2). ENV vars exported to your command: PORT, HOST.
  - Vite/Vue example: npm run dev -- --host 0.0.0.0 --port $PORT
  - Next.js example: npm run dev -p $PORT -H 0.0.0.0
EOF
}

load_env() {
  if [[ -f "${PROJECT_DIR}/.env" ]]; then
    # shellcheck disable=SC1090
    source "${PROJECT_DIR}/.env"
  fi
  # Ensure fallbacks if any are empty
  : "${BASHY_NAME:=${DEFAULT_NAME}}"
  : "${BASHY_PORT:=${DEFAULT_PORT}}"
  : "${BASHY_DOMAIN:=${DEFAULT_DOMAIN}}"
  : "${BASHY_WORKDIR:=${DEFAULT_WORKDIR}}"
  : "${BASHY_COMMAND:=${DEFAULT_COMMAND}}"
  : "${BASHY_ENV_EXTRA:=''}"
}

csv_to_inline_env_exports() {
  local csv="$1"
  local out=""
  if [[ -z "${csv}" ]]; then echo ""; return 0; fi
  IFS=',' read -r -a pairs <<< "${csv}"
  for pair in "${pairs[@]}"; do
    local key="${pair%%=*}"
    local val="${pair#*=}"
    [[ -z "${key}" ]] && continue
    # single-quote value safely
    out+=" ${key}='${val//'\''/'\'''}'"
  done
  echo "${out}"
}

ensure_pm2() {
  if ! command -v pm2 >/dev/null 2>&1; then
    print_err "pm2 not found. Install with: npm i -g pm2"
    exit 1
  fi
}

pm2_start() {
  load_env
  ensure_pm2
  local inline_env="PORT='${BASHY_PORT}' HOST='${BASHY_DOMAIN}'$(csv_to_inline_env_exports "${BASHY_ENV_EXTRA}")"
  # Use zsh login shell so nvm and PATH customizations load
  pm2 start /bin/zsh \
    --name "${BASHY_NAME}" \
    --cwd "${BASHY_WORKDIR}" \
    -- -lc "cd '${BASHY_WORKDIR}' && ${inline_env} ${BASHY_COMMAND}"
  print_info "PM2 started process ${BASHY_NAME}."
}

pm2_stop() {
  load_env
  ensure_pm2
  pm2 stop "${BASHY_NAME}" || true
  print_info "PM2 stop signaled for ${BASHY_NAME}."
}

pm2_restart() {
  load_env
  ensure_pm2
  if pm2 describe "${BASHY_NAME}" >/dev/null 2>&1; then
    pm2 restart "${BASHY_NAME}"
    print_info "PM2 restarted ${BASHY_NAME}."
  else
    pm2_start
  fi
}

pm2_delete() {
  load_env
  ensure_pm2
  pm2 delete "${BASHY_NAME}" || true
  print_info "PM2 deleted ${BASHY_NAME}."
}

update_env_var_in_file() {
  local file="$1"
  local key="$2"
  local value="$3"
  if [[ ! -f "${file}" ]]; then
    printf "%s=%s\n" "${key}" "${value}" > "${file}"
    return 0
  fi
  if grep -q "^${key}=" "${file}"; then
    # macOS sed requires an empty extension with -i ""
    sed -E -i '' "s|^${key}=.*$|${key}=${value}|" "${file}"
  else
    printf "%s=%s\n" "${key}" "${value}" >> "${file}"
  fi
}

up_cmd() {
  # If flags are provided or no config file, (re)initialize
  if [[ $# -gt 0 || ! -f "${PROJECT_DIR}/.env" ]]; then
    # init_cmd "$@" # Removed init_cmd
    print_info "Initializing new project or overriding existing .env"
    # Set default values for new project
    BASHY_NAME="${DEFAULT_NAME}"
    BASHY_PORT="${DEFAULT_PORT}"
    BASHY_DOMAIN="${DEFAULT_DOMAIN}"
    BASHY_WORKDIR="${DEFAULT_WORKDIR}"
    BASHY_COMMAND="${DEFAULT_COMMAND}"
    BASHY_ENV_EXTRA=""
  else
    load_env
  fi

  # Prepare application .env file from .env.example if available
  local env_example_path="${BASHY_WORKDIR}/.env.example"
  local env_path="${BASHY_WORKDIR}/.env"
  if [[ -f "${env_example_path}" && ! -f "${env_path}" ]]; then
    cp "${env_example_path}" "${env_path}"
    print_info "Copied ${env_example_path} -> ${env_path}"
  fi

  # Ensure PORT and HOST in .env match Bashy config (if there is an .env)
  if [[ -f "${env_path}" ]]; then
    update_env_var_in_file "${env_path}" "PORT" "${BASHY_PORT}"
    update_env_var_in_file "${env_path}" "HOST" "${BASHY_DOMAIN}"
    print_info "Updated ${env_path} with PORT=${BASHY_PORT} HOST=${BASHY_DOMAIN}"
  fi

  # Ensure bashy directory is ignored by the target project's git
  ensure_gitignore_bashy

  # Register the local domain and start (or restart) the PM2 service
  register_domain
  pm2_restart
  print_info "Service is up via PM2. Visit: http://${BASHY_DOMAIN}:${BASHY_PORT}"
}

status_agent() {
  load_env
  ensure_pm2
  pm2 status "${BASHY_NAME}" | cat
}

logs_cmd() {
  load_env
  ensure_pm2
  if [[ "${1:-}" == "--follow" ]]; then
    pm2 logs "${BASHY_NAME}"
  else
    pm2 logs "${BASHY_NAME}" --lines 200 | cat
  fi
}

register_domain() {
  load_env
  local ip="${1:-127.0.0.1}"
  local domain="${BASHY_DOMAIN}"
  if grep -q "[[:space:]]${domain}$" /etc/hosts; then
    print_info "Domain ${domain} already in /etc/hosts"
    return 0
  fi
  local tmpfile
  tmpfile="$(mktemp)"
  sudo cp /etc/hosts "${tmpfile}.orig"
  printf "%s\t%s\n" "${ip}" "${domain}" | sudo tee -a /etc/hosts >/dev/null
  rm -f "${tmpfile}" || true
  print_info "Added ${domain} -> ${ip} to /etc/hosts"
}

unregister_domain() {
  load_env
  local domain="${BASHY_DOMAIN}"
  if ! grep -q "[[:space:]]${domain}$" /etc/hosts; then
    print_info "Domain ${domain} not found in /etc/hosts"
    return 0
  fi
  local tmp
  tmp="$(mktemp)"
  sudo awk '!($2 == "'"${domain}"'")' /etc/hosts | sudo tee "${tmp}" >/dev/null
  sudo cp "${tmp}" /etc/hosts
  rm -f "${tmp}"
  print_info "Removed ${domain} from /etc/hosts"
}

# Ensure the embedded bashy directory is ignored by the target project's git
ensure_gitignore_bashy() {
  load_env
  local gitignore_path="${BASHY_WORKDIR}/.gitignore"
  local dir_name
  dir_name="$(basename "${SCRIPT_DIR}")"
  local entry="${dir_name}/"
  mkdir -p "${BASHY_WORKDIR}"
  touch "${gitignore_path}"
  if ! grep -qxF "${entry}" "${gitignore_path}"; then
    {
      echo "# managed by bashy"
      echo "${entry}"
    } >> "${gitignore_path}"
    print_info "Added ${entry} to ${gitignore_path}"
  else
    print_info "${entry} already present in ${gitignore_path}"
  fi
}

cmd="${1:-help}"
shift || true

case "${cmd}" in
  help|-h|--help) usage ;;
  up) up_cmd ;;
  start) pm2_start ;;
  stop) pm2_stop ;;
  restart) pm2_restart ;;
  delete) pm2_delete ;;
  save) ensure_pm2; pm2 save; print_info "PM2 process list saved." ;;
  status) status_agent ;;
  logs) logs_cmd "${1:-}" ;;
  register-domain) register_domain "${1:-}" ;;
  unregister-domain) unregister_domain ;;
  *) print_err "Unknown command: ${cmd}"; usage; exit 1 ;;
esac

