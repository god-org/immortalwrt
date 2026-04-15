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

function main {
  local pending_urls max_retries retry_wait attempt_idx
  local current_failed_list url repo_name target_dir

  pending_urls=(
    https://github.com/kongfl888/luci-app-adguardhome
    https://github.com/ophub/luci-app-amlogic
  )

  max_retries=3
  retry_wait=5

  for ((attempt_idx = 1; attempt_idx <= max_retries; attempt_idx++)); do
    log_info "正在开始第 $attempt_idx 轮同步任务（剩余任务：${#pending_urls[@]}）"
    current_failed_list=()

    for url in "${pending_urls[@]}"; do
      [[ -z $url || $url == '#'* ]] && continue

      repo_name=${url##*/}
      target_dir=package/$repo_name

      if [[ ! -d $target_dir ]]; then
        log_info "正在拉取：$repo_name"
        if git clone --depth=1 --single-branch "$url" "$target_dir"; then
          log_info "软件包 $repo_name 克隆成功"
        else
          log_error "软件包 $repo_name 克隆失败"
          rm -rf "$target_dir"
          current_failed_list+=("$url")
        fi
      else
        log_warn "目录 $target_dir 已存在，跳过拉取"
      fi
    done

    if ((!${#current_failed_list[@]})); then
      log_info "所有扩展软件包已成功就位"
      return 0
    fi

    pending_urls=("${current_failed_list[@]}")

    if ((attempt_idx < max_retries)); then
      log_warn "本轮有 ${#pending_urls[@]} 个任务失败，$retry_wait 秒后重试"
      sleep "$retry_wait"
    else
      log_error "已达最大重试次数，以下仓库拉取失败："
      printf '  - %s\n' "${pending_urls[@]}" >&2
      return 1
    fi
  done
}

main "$@"
