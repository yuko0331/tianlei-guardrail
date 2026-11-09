#!/bin/bash
# 打包 WorkBuddy 安全围栏插件，输出到 dist/：
#   tianlei-guardrail-workbuddy-<版本>.zip  发给个人使用：含安装脚本、说明和插件
#   tianlei-market-<版本>.zip         放到内网 HTTP 服务器，供 WorkBuddy 按 zip 市场拉取
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$ROOT/tianlei-guardrail/.codebuddy-plugin/plugin.json" | head -1)"
DIST="$ROOT/dist"
NAME="tianlei-guardrail-workbuddy-$VERSION"
STAGE="$DIST/$NAME"

rm -rf "$STAGE" "$DIST/$NAME.zip" "$DIST/tianlei-market-$VERSION.zip" "$DIST/tianlei-market.zip"
mkdir -p "$STAGE/market"

cp -R "$ROOT/.codebuddy-plugin" "$ROOT/tianlei-guardrail" "$STAGE/market/"
cp "$ROOT/installer/install.sh" "$ROOT/installer/install.ps1" "$ROOT/installer/README.md" "$STAGE/"
chmod +x "$STAGE/install.sh" "$STAGE/market/tianlei-guardrail/scripts/guard.mjs"
find "$STAGE" -name '.DS_Store' -delete

(cd "$DIST" && zip -qrX "$NAME.zip" "$NAME")
(cd "$STAGE/market" && zip -qrX "$DIST/tianlei-market-$VERSION.zip" .codebuddy-plugin tianlei-guardrail)
# 固定文件名的副本：放到内网服务器后地址不变，更新时直接替换这个文件
cp "$DIST/tianlei-market-$VERSION.zip" "$DIST/tianlei-market.zip"
rm -rf "$STAGE"

echo "已生成："
ls -lh "$DIST"/*.zip
