#!/bin/bash
# 刷新 GameCenter.app 图标（macOS 图标缓存 / quarantine 导致不显示时运行）
# 用法：把本脚本放在 GameCenter.app 同级目录，终端执行 `bash fix-icon.sh`
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$SCRIPT_DIR/GameCenter.app"

if [[ ! -d "$APP" ]]; then
  echo "未找到 $APP" >&2
  echo "请把本脚本放在 GameCenter.app 同级目录后再运行。" >&2
  exit 1
fi
if [[ ! -f "$APP/Contents/Resources/AppIcon.icns" ]]; then
  echo "错误：未找到 $APP/Contents/Resources/AppIcon.icns，图标文件缺失。" >&2
  exit 1
fi

echo "==> 1. 移除 quarantine 隔离标记（未签名 app 常见）"
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

echo "==> 2. 更新 app 修改时间，触发 Finder 重新读取"
touch "$APP"

echo "==> 3. 重置 QuickLook 缓存"
qlmanage -r >/dev/null 2>&1 || true

echo "==> 4. 清理双层图标缓存并重启相关服务（可能需要管理员密码）"
sudo rm -rf /Library/Caches/com.apple.iconservices.store 2>/dev/null || true
rm -rf ~/Library/Caches/com.apple.iconservices.store 2>/dev/null || true
killall -9 com.apple.IconServicesAgent 2>/dev/null || true
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true

echo "完成。请查看 GameCenter.app 图标是否更新。"
echo ""
echo "如果还是不显示，按这个顺序再试一次（关键）："
echo "  1) 把旧的 GameCenter.app 彻底删除并清空废纸篓（不要直接覆盖同名文件）"
echo "  2) 把新的 GameCenter.app 放到新位置（例如先放桌面）"
echo "  3) 重新运行本脚本"
echo "  4) 仍不行就注销或重启电脑，让图标服务彻底重建。"
