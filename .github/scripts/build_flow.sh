#!/usr/bin/env bash

. <(curl -fsSL "$BASH_LIB") || exit 1

sys_init() {
  lib::log_inf '初始化系统环境'
  lib::elev -E apt-get -qq update
  lib::elev -E apt-get -qq install $(<"$DEPS_FILE")
  lib::elev -E apt-get -qq autoremove --purge
  lib::elev -E apt-get -qq clean
  lib::elev timedatectl set-timezone "$TZ"

  lib::mk_d /workdir
  lib::elev chown "$USER:" /workdir
}

src_init() {
  lib::log_inf "准备源码：$IM_SRC [ $IM_VER ]"
  git clone -b "$IM_VER" --depth=1 --single-branch "$IM_SRC" /workdir/immortalwrt
  ln -sf /workdir/immortalwrt immortalwrt
}

src_feed() {
  lib::log_inf '同步 feeds 软件源'
  cd /workdir/immortalwrt || return 1
  ./scripts/feeds update -a
  ./scripts/feeds install -a
}

src_diy() {
  local ws=$GITHUB_WORKSPACE

  lib::log_inf '应用自定义配置'
  [[ -d $ws/$DIY_DIR ]] && cp -af "$ws/$DIY_DIR" /workdir/immortalwrt/
  [[ -f $ws/$DIY_CONF ]] && cp -af "$ws/$DIY_CONF" /workdir/immortalwrt/
  [[ -x $ws/$DIY_SH ]] || chmod +x "$ws/$DIY_SH"
  $ws/$DIY_SH
}

pkg_dl() {
  lib::log_inf '下载源码包'
  make defconfig
  make download -j"$(nproc)"

  find dl -size -1024c -exec ls -l {} +
  find dl -size -1024c -exec rm -f {} +
}

pkg_make() {
  lib::log_inf '执行固件编译'
  make -j"$(nproc)" || make -j1 || make -j1 V=s &&
    lib::log_inf '固件编译成功' && return 0 ||
    lib::log_err '固件编译失败' && return 1
}

res_meta() {
  local rel_name rel_tag build_t

  lib::log_inf '导出元数据'
  lib::now_t rel_name '%F %T'
  lib::now_t rel_tag '%Y%m%d%H%M%S'
  lib::now_t build_t '%Y年%m月%d日 %H时%M分%S秒'

  printf '%s\n' "rel_name=$rel_name" "rel_tag=$rel_tag" "build_t=$build_t" >>"$GITHUB_OUTPUT"
}

main() {
  sys_init
  src_init
  src_feed
  src_diy
  pkg_dl
  pkg_make
  res_meta
}

main "$@"
