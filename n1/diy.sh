#!/bin/bash

set -euo pipefail

git clone --depth=1 --single-branch https://github.com/kongfl888/luci-app-adguardhome package/luci-app-adguardhome
git clone --depth=1 --single-branch https://github.com/ophub/luci-app-amlogic package/luci-app-amlogic
