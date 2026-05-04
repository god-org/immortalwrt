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

bin_get() {
  local repo pattern bin_name dst_dir tmp_dir list file

  read -r repo pattern bin_name <<<"$1"
  dst_dir=files/usr/local/bin
  lib::tmp_d tmp_dir

  [[ $repo && $pattern && $bin_name ]] || return 1
  [[ -d $dst_dir ]] || lib::mk_d "$dst_dir"

  lib::log_inf "正在下载：$bin_name"

  if gh release download -R "$repo" -p "$pattern" -D "$tmp_dir" --clobber; then
    lib::log_inf "软件 $bin_name 下载成功"
  else
    lib::log_err "软件 $bin_name 下载失败"
    return 1
  fi

  list=("$tmp_dir"/$pattern)
  file=${list[0]}

  if [[ $file == *.@(gz|xz|zst) ]]; then
    tar -axf "$file" -C "$tmp_dir"
    find "$tmp_dir" -type f -name "$bin_name" -exec mv -f {} "$dst_dir/$bin_name" \;
  else
    mv -f "$file" "$dst_dir/$bin_name"
  fi

  [[ -f $dst_dir/$bin_name ]] || {
    lib::log_err "未找到软件：$bin_name"
    return 1
  }

  [[ -x $dst_dir/$bin_name ]] || chmod +x "$dst_dir/$bin_name"
  lib::log_inf "软件放置在：$dst_dir/$bin_name"
}

main() {
  local pkg_list bin_list

  pkg_list=(
    https://github.com/kongfl888/luci-app-adguardhome
    https://github.com/ophub/luci-app-amlogic
  )

  bin_list=(
    'ClementTsang/bottom *aarch64-unknown-linux-musl.tar.gz btm'
    'jesseduffield/lazydocker *Linux_arm64.tar.gz lazydocker'
  )

  lib::retry pkg_list pkg_get
  lib::retry bin_list bin_get
}

main "$@"
