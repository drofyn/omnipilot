#!/bin/bash
#
# Packages OmniPilot into a distributable artifact.
#
# Usage:
#   Scripts/package.sh              # Release 构建 + zip（默认）
#   Scripts/package.sh --dmg        # Release 构建 + dmg
#   Scripts/package.sh --all        # Release 构建 + zip 和 dmg
#
# 签名策略：
#   若钥匙串中存在 "Developer ID Application" 证书 → 用它签名（开启 hardened runtime）；
#   若同时还设置了环境变量 NOTARY_PROFILE（用 `xcrun notarytool store-credentials` 创建）
#   → 额外执行公证 + 装订票据。
#   否则 → ad-hoc 签名。这适合本机使用，以及通过 scp/rsync/U 盘 分发
#   （这些方式不会写 com.apple.quarantine，因此不会被 Gatekeeper 拦截）。
#
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="OmniPilot"
SCHEME="OmniPilot"
CONFIG="Release"
DIST_DIR="build/dist"

FORMAT="zip"
case "${1:-}" in
    --dmg) FORMAT="dmg" ;;
    --all) FORMAT="all" ;;
    --zip | "") FORMAT="zip" ;;
    -h | --help)
        sed -n '2,18p' "$0"
        exit 0
        ;;
    *)
        echo "unknown option: $1" >&2
        exit 1
        ;;
esac

VERSION="$(grep -E '^[[:space:]]*MARKETING_VERSION:' project.yml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
VERSION="${VERSION:-0.0.0}"
BASE_NAME="${APP_NAME}-${VERSION}"

command -v xcodegen >/dev/null 2>&1 || {
    echo "error: 未找到 xcodegen，请先执行： brew install xcodegen" >&2
    exit 1
}

echo "==> 生成工程"
xcodegen generate --quiet

echo "==> 构建 ${CONFIG}（${BASE_NAME}）"
mkdir -p build
BUILD_LOG="build/xcodebuild.log"
if ! xcodebuild \
    -project OmniPilot.xcodeproj \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -derivedDataPath build/DerivedData \
    build >"$BUILD_LOG" 2>&1; then
    echo "构建失败，日志末尾：" >&2
    tail -40 "$BUILD_LOG" >&2
    exit 1
fi

APP="build/DerivedData/Build/Products/$CONFIG/$APP_NAME.app"
if [ ! -d "$APP" ]; then
    echo "error: 未找到构建产物 $APP" >&2
    exit 1
fi

# ---- 签名 ----
IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | grep -o '"Developer ID Application:[^"]*"' \
    | head -1 | tr -d '"' || true)"

if [ -n "$IDENTITY" ]; then
    echo "==> 使用 Developer ID 签名：$IDENTITY"
    codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$APP"

    if [ -n "${NOTARY_PROFILE:-}" ]; then
        echo "==> 提交公证（keychain profile: $NOTARY_PROFILE）"
        ditto -c -k --keepParent "$APP" "build/$BASE_NAME-notarize.zip"
        xcrun notarytool submit "build/$BASE_NAME-notarize.zip" \
            --keychain-profile "$NOTARY_PROFILE" --wait
        rm -f "build/$BASE_NAME-notarize.zip"
        echo "==> 装订公证票据"
        xcrun stapler staple "$APP"
    else
        echo "    （未设置 NOTARY_PROFILE，跳过公证）"
    fi
else
    echo "==> 未找到 Developer ID 证书 → 使用 ad-hoc 签名"
    codesign --force --deep --sign - "$APP"
fi

echo "==> 校验签名"
codesign --verify --strict --verbose=2 "$APP" 2>&1 | sed 's/^/    /'

# ---- 打包 ----
mkdir -p "$DIST_DIR"

make_zip() {
    local out="$DIST_DIR/$BASE_NAME.zip"
    rm -f "$out"
    # 用 ditto 而非 zip：能完整保留签名、权限与扩展属性
    ditto -c -k --keepParent "$APP" "$out"
    echo "    $out"
}

make_dmg() {
    local out="$DIST_DIR/$BASE_NAME.dmg"
    rm -f "$out"
    local staging
    staging="$(mktemp -d)"
    cp -R "$APP" "$staging/"
    ln -s /Applications "$staging/Applications"
    hdiutil create -volname "$APP_NAME" -srcfolder "$staging" \
        -ov -format UDZO -quiet "$out"
    rm -rf "$staging"
    echo "    $out"
}

echo "==> 打包"
case "$FORMAT" in
    zip) make_zip ;;
    dmg) make_dmg ;;
    all)
        make_zip
        make_dmg
        ;;
esac

echo
echo "完成，产物在 $DIST_DIR/"
echo
echo "分发到另一台 Mac（scp 不会写 quarantine，ad-hoc 签名即可直接运行）："
echo "    scp $DIST_DIR/$BASE_NAME.zip <user>@<另一台>:~/"
echo "    # 在另一台上："
echo "    cd ~ && ditto -x -k $BASE_NAME.zip . && mv $APP_NAME.app /Applications/"
echo
echo "注意：不要用 AirDrop / 浏览器 / 网盘传输 —— 它们会写入 com.apple.quarantine，"
echo "      未公证的 App 会被 Gatekeeper 拦截。"
