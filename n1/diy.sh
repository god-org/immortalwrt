#!/bin/bash

# Git 稀疏克隆，只克隆指定目录到本地
# function git_sparse_clone() {
#     branch="$1" repourl="$2" && shift 2
#     git clone -b "$branch" --depth=1 --single-branch --filter=blob:none --sparse "$repourl"
#     repodir=$(echo "$repourl" | awk -F '/' '{print $(NF)}')
#     cd "$repodir" && git sparse-checkout set "$@"
#     mv -f "$@" ../package
#     cd .. && rm -rf "$repodir"
# }

# 添加插件包
git clone --depth=1 --single-branch "https://github.com/kongfl888/luci-app-adguardhome" "package/luci-app-adguardhome"
git clone --depth=1 --single-branch "https://github.com/ophub/luci-app-amlogic" "package/luci-app-amlogic"

# 修改默认地址
# sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# 修改主机名
# sed -i 's/ImmortalWrt/n1/g' package/base-files/files/bin/config_generate
