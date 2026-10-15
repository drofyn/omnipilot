#!/bin/bash
#
# 从 Design/OmniPilot.svg 生成：
#   - Resources/AppIcon.icns             应用图标（Finder / 关于页）
#   - Resources/MenuBarIcon.png          菜单栏状态图标（模板图，18pt）
#   - Resources/MenuBarIcon@2x.png       同上 @2x（36px）
# 从 Design/OmniPilotError.svg 生成：
#   - Resources/MenuBarIconError.png     菜单栏“失败态”图标（模板图，18pt）
#   - Resources/MenuBarIconError@2x.png  同上 @2x（36px）
#
# 用 Scripts/RenderIcon.swift 直接光栅化 SVG：保留透明通道、尺寸精确。
# （不用 qlmanage —— 它会给 SVG 铺不透明白底，模板图会变成白方块。）
#
set -euo pipefail

cd "$(dirname "$0")/.."

SVG="Design/OmniPilot.svg"
if [ ! -f "$SVG" ]; then
    echo "error: 找不到图标源文件 $SVG" >&2
    exit 1
fi

ERROR_SVG="Design/OmniPilotError.svg"
if [ ! -f "$ERROR_SVG" ]; then
    echo "error: 找不到菜单栏失败态图标源文件 $ERROR_SVG" >&2
    exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET" Resources

echo "==> 光栅化 SVG"
swift Scripts/RenderIcon.swift "$SVG" \
    16   "$ICONSET/icon_16x16.png" \
    32   "$ICONSET/icon_16x16@2x.png" \
    32   "$ICONSET/icon_32x32.png" \
    64   "$ICONSET/icon_32x32@2x.png" \
    128  "$ICONSET/icon_128x128.png" \
    256  "$ICONSET/icon_128x128@2x.png" \
    256  "$ICONSET/icon_256x256.png" \
    512  "$ICONSET/icon_256x256@2x.png" \
    512  "$ICONSET/icon_512x512.png" \
    1024 "$ICONSET/icon_512x512@2x.png" \
    18   "Resources/MenuBarIcon.png" \
    36   "Resources/MenuBarIcon@2x.png"

echo "==> 光栅化菜单栏失败态 SVG"
swift Scripts/RenderIcon.swift "$ERROR_SVG" \
    18   "Resources/MenuBarIconError.png" \
    36   "Resources/MenuBarIconError@2x.png"

echo "==> 合成 AppIcon.icns"
iconutil -c icns "$ICONSET" -o "Resources/AppIcon.icns"

echo "==> 完成"
ls -lh Resources/AppIcon.icns \
    Resources/MenuBarIcon.png Resources/MenuBarIcon@2x.png \
    Resources/MenuBarIconError.png Resources/MenuBarIconError@2x.png
