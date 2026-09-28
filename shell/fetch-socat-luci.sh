#!/bin/sh
# 从 chenmozhijin/luci-app-socat 下载预编译 ipk 并解包到仓库 files/ 目录
#
# 背景：ImmortalWrt 25.12 官方源及第三方源(apk) 都没有 luci-app-socat 的 LuCI 界面，
#       且上游只发布 ipk(Architecture: all)。因为该包全是架构无关的 Lua/JSON 文件，
#       所以采用「files/ 覆盖」的方式集成，再由 x86-64/build25.sh 安装 socat/luci-compat/luci-lua-runtime 依赖。
#
# 用法: sh shell/fetch-socat-luci.sh [目标目录，默认 files]
set -eu

VER="${SOCAT_LUCI_VER:-20250726}"
APP_IPK="${SOCAT_APP_IPK:-luci-app-socat_${VER}_all.ipk}"
I18N_IPK="${SOCAT_I18N_IPK:-luci-i18n-socat-zh-cn_0.250726.15964_all.ipk}"
BASE="${SOCAT_BASE:-https://github.com/chenmozhijin/luci-app-socat/releases/download/v${VER}}"
DEST="${1:-files}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

for ipk in "$APP_IPK" "$I18N_IPK"; do
    echo "⏬ 下载 $BASE/$ipk"
    curl -fsSL -o "$TMP/$ipk" "$BASE/$ipk"
done

mkdir -p "$TMP/x"
for ipk in "$APP_IPK" "$I18N_IPK"; do
    d="$TMP/x/${ipk%.ipk}"
    mkdir -p "$d"
    # ipk 可能是 ar 封装，也可能像本仓库一样是 tar 封装，两种都兼容
    if tar -xf "$TMP/$ipk" -C "$d" 2>/dev/null; then
        :
    else
        ( cd "$d" && ar x "$TMP/$ipk" )
    fi
    mkdir -p "$d/data"
    tar -xf "$d"/data.tar.gz -C "$d/data" 2>/dev/null || tar -xf "$d"/data.tar.* -C "$d/data"
    cp -a "$d/data/." "$DEST/"
done

# 修正执行权限（init 脚本、uci-defaults 需要可执行）
[ -f "$DEST/etc/init.d/luci_socat" ] && chmod 755 "$DEST/etc/init.d/luci_socat"
[ -f "$DEST/etc/uci-defaults/luci-app-socat" ] && chmod 755 "$DEST/etc/uci-defaults/luci-app-socat"

echo "✅ luci-app-socat 已解包到 $DEST/"
