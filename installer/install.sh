#!/bin/bash
# 天磊安全围栏 WorkBuddy 插件：macOS 一键安装 / 卸载
#
# 安装：bash install.sh [--scan-url URL] [--fail-mode open|closed]
# 卸载：bash install.sh --uninstall
#
# 做的事情：
#   1. 把插件复制到 ~/.tianlei-guardrail/market
#   2. 首次安装时写入 ~/.tianlei-guardrail/hook.json（已存在则保留）
#   3. 备份 ~/.workbuddy/settings.json，再登记插件市场并启用插件
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCAN_URL="http://192.168.120.68:18000/v1/scan"
FAIL_MODE="open"
ACTION="install"

while [ $# -gt 0 ]; do
  case "$1" in
    --scan-url)  SCAN_URL="$2"; shift 2 ;;
    --fail-mode) FAIL_MODE="$2"; shift 2 ;;
    --uninstall) ACTION="uninstall"; shift ;;
    *) echo "未知参数：$1"; exit 1 ;;
  esac
done

if [ "$FAIL_MODE" != "open" ] && [ "$FAIL_MODE" != "closed" ]; then
  echo "--fail-mode 只能是 open 或 closed"; exit 1
fi

GUARD_DIR="$HOME/.tianlei-guardrail"
MARKET_DIR="$GUARD_DIR/market"
WB_DIR="$HOME/.workbuddy"
SETTINGS="$WB_DIR/settings.json"

if [ ! -d "$WB_DIR" ]; then
  echo "未找到 ${WB_DIR}，请先安装 WorkBuddy 并至少打开一次。"; exit 1
fi

# 用系统自带的 JavaScript for Automation 修改 settings.json，不依赖 node 或 python
patch_settings() {
  local action="$1"
  local mode="600"
  [ -f "$SETTINGS" ] && mode="$(stat -f '%Lp' "$SETTINGS")"
  osascript -l JavaScript - "$action" "$SETTINGS" "$MARKET_DIR" <<'JXA'
function run(argv) {
  const [action, file, marketDir] = argv;
  let data = {};
  if ($.NSFileManager.defaultManager.fileExistsAtPath(file)) {
    const text = ObjC.unwrap($.NSString.stringWithContentsOfFileEncodingError(file, $.NSUTF8StringEncoding, null));
    if (text && text.trim()) data = JSON.parse(text);
  }
  const pluginKey = 'tianlei-guardrail@tianlei-market';
  data.extraKnownMarketplaces = data.extraKnownMarketplaces || {};
  data.enabledPlugins = data.enabledPlugins || {};
  if (action === 'install') {
    data.extraKnownMarketplaces['tianlei-market'] = { source: { source: 'directory', path: marketDir } };
    data.enabledPlugins[pluginKey] = true;
  } else {
    delete data.extraKnownMarketplaces['tianlei-market'];
    data.enabledPlugins[pluginKey] = false; // 显式停用，避免已缓存的插件按默认启用继续生效
  }
  const content = $.NSString.alloc.initWithUTF8String(JSON.stringify(data, null, 2));
  if (!content.writeToFileAtomicallyEncodingError(file, true, $.NSUTF8StringEncoding, null)) {
    throw new Error('写入 settings.json 失败');
  }
  return 'settings.json 已更新';
}
JXA
  chmod "$mode" "$SETTINGS"
}

backup_settings() {
  if [ -f "$SETTINGS" ]; then
    local backup="$SETTINGS.bak-tianlei-guardrail-$(date +%Y%m%d%H%M%S)"
    cp -p "$SETTINGS" "$backup"
    echo "已备份原配置：$backup"
  fi
}

if [ "$ACTION" = "install" ]; then
  mkdir -p "$GUARD_DIR"
  chmod 700 "$GUARD_DIR"
  rm -rf "$MARKET_DIR"
  cp -R "$HERE/market" "$MARKET_DIR"
  echo "插件已复制到：$MARKET_DIR"

  if [ -f "$GUARD_DIR/hook.json" ]; then
    echo "保留已有检测配置：$GUARD_DIR/hook.json"
  else
    cat > "$GUARD_DIR/hook.json" <<EOF
{
  "scanUrl": "$SCAN_URL",
  "failMode": "$FAIL_MODE"
}
EOF
    chmod 600 "$GUARD_DIR/hook.json"
    echo "已写入检测配置：$GUARD_DIR/hook.json"
  fi

  backup_settings
  patch_settings install
  echo ""
  echo "安装完成。请完全退出 WorkBuddy（⌘Q）后重新打开。"
  echo "检测日志：$GUARD_DIR/hook.log"
else
  backup_settings
  patch_settings uninstall
  rm -rf "$MARKET_DIR"
  echo ""
  echo "已停用并移除插件。检测配置和日志保留在 ${GUARD_DIR}，可手动删除。"
  echo "请完全退出 WorkBuddy（⌘Q）后重新打开。"
fi
