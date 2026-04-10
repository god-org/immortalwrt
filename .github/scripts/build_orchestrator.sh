#!/usr/bin/env bash

set -euxo pipefail

if ((BASH_VERSINFO[0] < 4)); then
  printf '❌ 要求 Bash 版本 ≥ 4.0，当前版本：%s。\n' "$BASH_VERSION" >&2
  exit 127
fi

function log_info {
  printf '[%(%F %T)T] ✅：%s。\n' -1 "$*" >&2
}

function log_warn {
  printf '[%(%F %T)T] ⚠️：%s。\n' -1 "$*" >&2
}

function log_error {
  printf '[%(%F %T)T] ❌：%s。\n' -1 "$*" >&2
}

function init_build_env {
  log_info "正在初始化编译环境并安装依赖"
  sudo -E apt-get -qq update
  sudo -E apt-get -qq install $(<"$DEPENDENCIES_FILE")
  sudo -E apt-get -qq autoremove --purge
  sudo -E apt-get -qq clean
  sudo timedatectl set-timezone "$TZ"

  sudo mkdir -p /workdir
  sudo chown "$USER:" /workdir
}

function setup_source_code {
  log_info "正在克隆源码仓库：$REPO_BRANCH"
  git clone -b "$REPO_BRANCH" --depth=1 --single-branch "$REPO_URL" /workdir/immortalwrt
  ln -sf /workdir/immortalwrt immortalwrt
}

function manage_feeds {
  log_info "正在更新与安装 feeds 软件源"
  cd /workdir/immortalwrt
  ./scripts/feeds update -a
  ./scripts/feeds install -a
}

function apply_customization {
  local workspace=$GITHUB_WORKSPACE

  log_info "正在应用自定义配置与 DIY 脚本"
  [[ -d $workspace/$DIY_FILES ]] && cp -af "$workspace/$DIY_FILES" /workdir/immortalwrt/
  [[ -f $workspace/$DIY_CONFIG ]] && cp -af "$workspace/$DIY_CONFIG" /workdir/immortalwrt/
  [[ -x $workspace/$DIY_SCRIPT ]] || chmod +x "$workspace/$DIY_SCRIPT"
  "$workspace/$DIY_SCRIPT"
}

function download_dependencies {
  log_info "正在并行下载编译所需源码包"
  make defconfig
  make download -j"$(nproc)"

  find dl -size -1024c -exec ls -l {} \;
  find dl -size -1024c -exec rm -f {} \;
}

function execute_compilation {
  log_info "开始执行固件编译逻辑"
  if make -j"$(nproc)" || make -j1 || make -j1 V=s; then
    log_info "固件编译成功"
  else
    log_error "固件编译失败"
    exit 1
  fi
}

function export_metadata {
  local release_name release_tag build_time

  printf -v release_name '%(%F %T)T' -1
  printf -v release_tag '%(%Y%m%d%H%M%S)T' -1
  printf -v build_time '%(%Y年%m月%d日 %H时%M分%S秒)T' -1

  {
    echo 'COMPILE_STATUS=success'
    echo "RELEASE_NAME=$release_name"
    echo "RELEASE_TAG=$release_tag"
    echo "BUILD_TIME=$build_time"
  } >>"$GITHUB_ENV"
}

function main {
  init_build_env
  setup_source_code
  manage_feeds
  apply_customization
  download_dependencies
  execute_compilation
  export_metadata
}

main "$@"
