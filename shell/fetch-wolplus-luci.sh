#!/bin/sh
# 从 animegasan/luci-app-wolplus(源自 sundaqiang) 下载预编译 ipk 并解包到仓库 files/ 目录
#
# 背景：ImmortalWrt 25.12 官方源及第三方源(apk) 都没有 luci-app-wolplus，
#       且上游只发布 ipk(Architecture: all)。该包全是架构无关的 Lua/JSON 文件，
#       所以采用「files/ 覆盖」方式集成，运行时仅需官方源的 etherwake 依赖。
#
# 用法: sh shell/fetch-wolplus-luci.sh [目标目录，默认 files]
set -eu

VER="${WOLPLUS_VER:-1.1}"
REPO="${WOLPLUS_REPO:-animegasan/luci-app-wolplus}"
IPK="luci-app-wolplus_${VER}_all.ipk"
URL="${WOLPLUS_URL:-https://github.com/${REPO}/releases/download/${VER}/${IPK}}"
DEST="${1:-files}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

echo "⏬ 下载 $URL"
curl -fsSL -o "$TMP/$IPK" "$URL"

mkdir -p "$TMP/x"
# ipk 可能是 ar 封装，也可能是 tar 封装，两种都兼容
if tar -xf "$TMP/$IPK" -C "$TMP/x" 2>/dev/null; then
    :
else
    ( cd "$TMP/x" && ar x "$TMP/$IPK" )
fi
mkdir -p "$TMP/data"
tar -xf "$TMP/x"/data.tar.gz -C "$TMP/data" 2>/dev/null || tar -xf "$TMP/x"/data.tar.* -C "$TMP/data"

cp -a "$TMP/data/." "$DEST/"
echo "✅ luci-app-wolplus 已解包到 $DEST/"
