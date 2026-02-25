#!/bin/bash

set -euo pipefail

if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "❌ 要求 Bash 版本 ≥ 4.0，当前版本：${BASH_VERSION}。" >&2
  exit 127
fi

ADGUARD_URL='https://github.com/kongfl888/luci-app-adguardhome'
AMLOGIC_URL='https://github.com/ophub/luci-app-amlogic'
PKG_PATH='package'

function clone_packages() {
  local adguard_target amlogic_target

  adguard_target="${PKG_PATH}/luci-app-adguardhome"
  amlogic_target="${PKG_PATH}/luci-app-amlogic"

  if [[ ! -d "${adguard_target}" ]]; then
    git clone --depth=1 --single-branch "${ADGUARD_URL}" "${adguard_target}"
  fi

  if [[ ! -d "${amlogic_target}" ]]; then
    git clone --depth=1 --single-branch "${AMLOGIC_URL}" "${amlogic_target}"
  fi
}

function main() {
  clone_packages
}

main "$@"

unset -f clone_packages main
unset ADGUARD_URL AMLOGIC_URL PKG_PATH
