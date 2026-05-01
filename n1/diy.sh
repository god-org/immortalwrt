#!/usr/bin/env bash

. <(curl -fsSL "$BASH_LIB") || exit 1

pkg_get() {
  local src_url=$1 pkg_name pkg_dir

  pkg_name=${src_url##*/}
  pkg_dir=package/$pkg_name

  [[ -d $pkg_dir ]] && return

  lib::log_inf "正在拉取：$pkg_name"

  if git clone --depth=1 --single-branch "$src_url" "$pkg_dir"; then
    lib::log_inf "软件包 $pkg_name 拉取成功"
  else
    lib::log_err "软件包 $pkg_name 拉取失败"
    rm -rf "$pkg_dir"
    return 1
  fi
}

main() {
  local pkg_list

  pkg_list=(
    https://github.com/kongfl888/luci-app-adguardhome
    https://github.com/ophub/luci-app-amlogic
  )

  lib::retry pkg_list pkg_get
}

main "$@"
