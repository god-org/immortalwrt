#!/bin/bash

set -euxo pipefail

if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "❌ 要求 Bash 版本 ≥ 4.0，当前版本：${BASH_VERSION}。" >&2
  exit 127
fi

SOURCE_DIR='/workdir/immortalwrt'
WORKSPACE_LINK="${GITHUB_WORKSPACE:-.}/immortalwrt"

function log() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] ✅：${*}。"
}

function error() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] ❌：${*}。" >&2
}

function init_build_env() {
  local deps_path tz_val
  deps_path="${GITHUB_WORKSPACE:-.}/${DEPENDENCIES_FILE:-}"
  tz_val="${TZ:-Asia/Shanghai}"

  log "正在初始化编译环境并安装依赖"
  sudo -E apt-get -qq update
  # shellcheck disable=SC2046
  sudo -E apt-get -qq install $(<"${deps_path}")
  sudo -E apt-get -qq autoremove --purge
  sudo -E apt-get -qq clean
  sudo timedatectl set-timezone "${tz_val}"

  sudo mkdir -p "${SOURCE_DIR%/*}"
  sudo chown "${USER}:${GROUPS[0]}" "${SOURCE_DIR%/*}"
}

function setup_source_code() {
  local repo_url repo_branch
  repo_url="${REPO_URL:-}"
  repo_branch="${REPO_BRANCH:-}"

  log "正在克隆源码仓库：${repo_branch}"
  git clone -b "${repo_branch}" --depth=1 --single-branch "${repo_url}" "${SOURCE_DIR}"
  ln -sf "${SOURCE_DIR}" "${WORKSPACE_LINK}"
}

function manage_feeds() {
  log "正在更新与安装 feeds 软件源"
  ./scripts/feeds update -a
  ./scripts/feeds install -a
}

function apply_customization() {
  local files_src config_src diy_script
  files_src="${GITHUB_WORKSPACE:-.}/${DIY_FILES:-}"
  config_src="${GITHUB_WORKSPACE:-.}/${DIY_CONFIG:-}"
  diy_script="${GITHUB_WORKSPACE:-.}/${DIY_SCRIPT:-}"

  log "正在应用自定义配置与 DIY 脚本"
  [[ -d "${files_src}" ]] && mv -f "${files_src}" "${SOURCE_DIR}/"
  [[ -f "${config_src}" ]] && mv -f "${config_src}" "${SOURCE_DIR}/"

  if [[ -f "${diy_script}" ]]; then
    [[ ! -x "${diy_script}" ]] && chmod +x "${diy_script}"
    "${diy_script}"
  fi
}

function download_dependencies() {
  local thread_count
  thread_count=$(nproc)

  log "正在并行下载编译所需源码包"
  make defconfig
  make download -j"${thread_count}"

  find dl -size -1024c -exec ls -l {} \;
  find dl -size -1024c -exec rm -f {} \;
}

function execute_compilation() {
  local thread_count
  thread_count=$(nproc)

  log "开始执行固件编译逻辑"

  if make -j"${thread_count}" || make -j1 || make -j1 V=s; then
    log "固件编译任务成功完成"
  else
    error "固件编译过程发生失败"
    exit 1
  fi
}

function export_metadata() {
  local release_name release_tag build_time

  printf -v release_name "%(%Y-%m-%dT%H:%M:%S%z)T" -1
  printf -v release_tag "%(%Y%m%d%H%M%S)T" -1
  printf -v build_time "%(%Y年%m月%d日 %H时%M分%S秒)T" -1

  {
    echo "compile_status=success"
    echo "RELEASE_NAME=${release_name}"
    echo "RELEASE_TAG=${release_tag}"
    echo "BUILD_TIME=${build_time}"
  } >>"${GITHUB_ENV}"
}

function main() {
  init_build_env
  setup_source_code
  cd "${SOURCE_DIR}"
  manage_feeds
  apply_customization
  download_dependencies
  execute_compilation
  export_metadata
}

main "$@"

unset -f log error init_build_env setup_source_code manage_feeds apply_customization download_dependencies execute_compilation export_metadata main
unset SOURCE_DIR WORKSPACE_LINK
