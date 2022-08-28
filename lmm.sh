#!/usr/bin/bash

set -e

#
# Global section
#

MAJOR_VERSION=0
MINOR_VERSION=1

CACHE_DIR=".lmm-cache"
LOG_FILE="${CACHE_DIR}/log.txt"

INSTALL_ROLE_FILE=".install.yml"

APP_PATH="$(dirname "$(readlink -f "$0")")"

cd "${APP_PATH}"
mkdir -p "${CACHE_DIR}"

#
# Logs
#
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NO_COLOR='\033[0m'

log_error() {
  echo -e "${RED}$*${NO_COLOR}" | tee -a "${LOG_FILE}"
}

log_warn() {
  echo -e "${YELLOW}$*${NO_COLOR}" | tee -a "${LOG_FILE}"
}

log_info() {
  echo -e "${GREEN}$*${NO_COLOR}" | tee -a "${LOG_FILE}"
}

case_error() {
  echo "$(log_error "Error:") Unsupported param '$(log_warn "$1")' in args line: $2" >&2
  exit 1
}

#
# Functions
#

init_ansible() {
  if [ -f "${CACHE_DIR}/${MAJOR_VERSION}" ]; then
    return
  fi

  rm -rf "${CACHE_DIR:?}"/* "collections"

  #https://docs.ansible.com/ansible/latest/galaxy/user_guide.html#install-multiple-collections-with-a-requirements-file
  #current roles don't require extra roles or collections
  cat >/tmp/ansible_requirements.yml <<EOF
---
EOF

  # shellcheck disable=SC2094
  ansible-galaxy role install -fr /tmp/ansible_requirements.yml \
    -p ./roles 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"
  # shellcheck disable=SC2094
  ansible-galaxy collection install -fr /tmp/ansible_requirements.yml \
    -p ./collections/ansible_collections 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"

  date >"${CACHE_DIR}/${MAJOR_VERSION}"
}

check_sudo_session() {
  if [ "$EUID" = 0 ]; then
    log_error "Don't run lmm as superuser. Please use sudo session. You can start it with 'sudo true' command"
    exit 1
  fi

  if sudo -n true 2>/dev/null; then
    log_info "Sudo session is ACTIVE"
  else
    log_info "Sudo session is disabled"
  fi

  exit
}

install() {
  role=${1:?}

  # shellcheck disable=SC2207
  shell_vars=($( (cd roles/"${role}"/vars/ && ls *.sh) 2>/dev/null))

  vars_for_yml=''
  for sv in "${shell_vars[@]}"; do
    vars_for_yml="${vars_for_yml}    ${sv/.sh/}: \"{{ $(cd roles/"${role}"/vars/ && sh "$sv") }}\"\n"
  done

  cat >${INSTALL_ROLE_FILE} <<EOF
---
- hosts: localhost
  connection: local

  vars:
    _user: "{{ ansible_env.USER }}"
$(echo -e "$vars_for_yml")

  roles:
  - role: ${role}
    tags: ${role}
EOF

  # disable outside roles to prevent names clash
  export DEFAULT_ROLES_PATH=''
  export ANSIBLE_ROLES_PATH=''

  ansible-playbook "${INSTALL_ROLE_FILE}" -t "${role}" 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"

  if [ "${PIPESTATUS[0]}" != '0' ]; then
    tail -n 20 "${LOG_FILE}"
    log_error "Error occurred. Last 20 lines from log above. ${APP_PATH}/${LOG_FILE}"
    log_info "If ROLE requires sudo. You have to run 'sudo true' before calling 'lmm install'"
    exit 1
  fi
}

test() {
  if ! which docker >/dev/null 2>&1; then
    log_warn "Tests requires installed docker"
    log_warn "Use: lmm install kato.docker"
  fi

  docker build -t testing-lmm -f ./test/Dockerfile .
  docker run -e "TEST_ROLE=$1" --rm testing-lmm
}

#
# MAIN
#

echo "  :: Start at $(date)" >>"${LOG_FILE}"

init_ansible

check_sudo_session

case "$1" in

help) # - this help
  echo -e "$(grep -E '^[[:space:]]*[[:alnum:][:space:]|-]+\).*$' "$0" | sed -e 's/) # / /')"
  ;;

version) # - print current version
  log_info "${MAJOR_VERSION}.${MINOR_VERSION}"
  ;;

l | list) # - list all available roles
  ls -1 ./roles/
  ;;

s | search) # \033[0;35mSUBSTRING\033[0m - grep through the list
  # shellcheck disable=SC2010
  ls -1 ./roles/ | grep -i "$2"
  ;;

i | install) # \033[0;35mROLE_NAME\033[0m - install ansible role from ./roles
  if [ "$2" = '' ]; then
    log_error "please provide the ROLE_NAME"
    exit 1
  else
    install "$2"
  fi
  ;;

test) # \033[0;35m[ROLE_NAME]\033[0m - install given role in a docker container, otherwise installs all roles
  test "$2"
  ;;

*)
  case_error "$1" "$@"
  ;;

esac
