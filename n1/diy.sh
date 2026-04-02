#!/usr/bin/env bash

set -euxo pipefail

if ((BASH_VERSINFO[0] < 4)); then
  printf '❌ 要求 Bash 版本 ≥ 4.0，当前版本：%s。\n' "${BASH_VERSION}" >&2
  exit 127
fi

umask 077

PKG_BASE_PATH='package'
PKG_MAX_RETRIES=3
PKG_RETRY_DELAY=5

REQUIRED_TOOLS=('git')

EXTRA_PACKAGES_URLS=(
  'https://github.com/kongfl888/luci-app-adguardhome'
  'https://github.com/ophub/luci-app-amlogic'
)

function get_current_time() {
  local time_format
  local -n time_ptr="${2}"
  time_format="${1:-%Y-%m-%d %H:%M:%S}"
  # shellcheck disable=SC2034
  printf -v time_ptr "%(${time_format})T" -1
}

function log_info() {
  local log_time
  get_current_time "" 'log_time'
  printf '[%s] ✅：%s。\n' "${log_time}" "${*}"
}

function log_warn() {
  local log_time
  get_current_time "" 'log_time'
  printf '[%s] ⚠️：%s。\n' "${log_time}" "${*}" >&2
}

function log_error() {
  local log_time
  get_current_time "" 'log_time'
  printf '[%s] ❌：%s。\n' "${log_time}" "${*}" >&2
}

function main() {
  local tool_list dep pkg_base_path max_retries retry_wait
  local pending_urls attempt_idx current_failed_list url repo_name target_dir

  tool_list=("${REQUIRED_TOOLS[@]}")
  for dep in "${tool_list[@]}"; do
    if ! command -v "${dep}" &>/dev/null; then
      log_error "系统缺失必要工具：${dep}，请先安装"
      exit 127
    fi
  done

  pkg_base_path="${PKG_BASE_PATH}"
  max_retries="${PKG_MAX_RETRIES}"
  retry_wait="${PKG_RETRY_DELAY}"
  pending_urls=("${EXTRA_PACKAGES_URLS[@]}")

  attempt_idx=1
  while ((attempt_idx <= max_retries)); do
    log_info "正在开始第 ${attempt_idx} 轮同步任务 (剩余任务: ${#pending_urls[@]})"
    current_failed_list=()

    for url in "${pending_urls[@]}"; do
      [[ -z "${url}" || "${url}" == '#'* ]] && continue

      repo_name="${url##*/}"
      target_dir="${pkg_base_path}/${repo_name}"

      if [[ ! -d "${target_dir}" ]]; then
        log_info "正在拉取：[ ${repo_name} ]"
        if git clone --depth=1 --single-branch "${url}" "${target_dir}"; then
          log_info "软件包 ${repo_name} 克隆成功"
        else
          log_error "软件包 ${repo_name} 克隆失败"
          current_failed_list+=("${url}")
        fi
      else
        log_warn "目录 ${target_dir} 已存在，跳过拉取"
      fi
    done

    if ((${#current_failed_list[@]} == 0)); then
      log_info "所有扩展软件包已成功就位"
      break
    fi

    pending_urls=("${current_failed_list[@]}")

    if ((attempt_idx < max_retries)); then
      log_error "本轮有 ${#pending_urls[@]} 个任务失败，${retry_wait} 秒后重试"
      sleep "${retry_wait}"
    else
      log_error "已达到最大重试次数，以下仓库拉取失败："
      printf '  - %s\n' "${pending_urls[@]}" >&2
      exit 1
    fi

    ((attempt_idx++))
  done
}

main "$@"

unset -f get_current_time log_info log_warn log_error main
unset PKG_BASE_PATH PKG_MAX_RETRIES PKG_RETRY_DELAY REQUIRED_TOOLS EXTRA_PACKAGES_URLS
