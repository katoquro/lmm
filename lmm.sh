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
  cat >/tmp/ansible_requirements.yml <<EOF
---
collections:
- community.general
EOF

  # shellcheck disable=SC2094
  ansible-galaxy role install -fr /tmp/ansible_requirements.yml \
    -p ./roles 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"
  # shellcheck disable=SC2094
  ansible-galaxy collection install -fr /tmp/ansible_requirements.yml \
    -p ./collections/ansible_collections 2>>"${LOG_FILE}" | tee -a "${LOG_FILE}"

  date >"${CACHE_DIR}/${MAJOR_VERSION}"
}

install() {
  role=${1:?}

  cat >${INSTALL_ROLE_FILE} <<EOF
---
- hosts: localhost

  vars:
    _user: "{{ ansible_env.USER }}"

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
  fi
}

#
# MAIN
#

echo "  :: Start at $(date)" >>"${LOG_FILE}"

init_ansible

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

*)
  case_error "$1" "$@"
  ;;

esac
