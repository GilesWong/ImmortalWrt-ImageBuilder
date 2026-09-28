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

# wolplus 的 etc/config/wolplus 会被 x86 工作流的 custom 挂载遮蔽，
# 这里删掉它，改由 files/etc/uci-defaults/97-wolplus-config 在首次启动时创建。
rm -f "$DEST/etc/config/wolplus"
rmdir "$DEST/etc/config" 2>/dev/null || true

# 上游自带 po 的 msgid 与代码不符，翻译不生效；用仓库里修正后的 po 生成 lmo。
SELFDIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if command -v python3 >/dev/null 2>&1; then
    mkdir -p "$DEST/usr/lib/lua/luci/i18n"
    python3 "$SELFDIR/po2lmo.py" "$SELFDIR/wolplus-zh-cn.po" "$DEST/usr/lib/lua/luci/i18n/wolplus.zh-cn.lmo"
else
    echo "⚠️ 未找到 python3，跳过 wolplus.zh-cn.lmo 生成（仓库中已有该文件）"
fi

echo "✅ luci-app-wolplus 已解包到 $DEST/"
