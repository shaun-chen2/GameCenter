#!/bin/bash
# 把 GameCenter.app 打包成 GameCenter.dmg（标准“拖到应用程序”安装盘）
# 若本机已安装 dmgbuild（pip install dmgbuild），则生成带背景图/.DS_Store 的精美安装盘；
# 否则退化为普通 hdiutil 压缩 DMG。
set -e
cd "$(dirname "$0")"

APP="GameCenter.app"
DMG="GameCenter.dmg"
VOL="GameCenter"
SETTINGS="dmg-settings.py"
BG="Assets/dmg/background.png"
STAGE="build/dmg"

if [[ ! -d "$APP" ]]; then
  echo "未找到 $APP，请先确认 app 已打包。" >&2
  exit 1
fi

# 尝试 dmgbuild 精美安装盘
if command -v dmgbuild >/dev/null 2>&1 && [[ -f "$SETTINGS" ]] && [[ -f "$BG" ]]; then
  echo "==> 使用 dmgbuild 生成带背景安装引导的 DMG"
  rm -f "$DMG"
  dmgbuild -s "$SETTINGS" "$VOL" "$DMG"
  echo "==> 完成："
  ls -la "$DMG"
  echo ""
  echo "使用：双击 $DMG 挂载，按背景图提示把 GameCenter.app 拖到 Applications 即可。"
  exit 0
fi

# Fallback：普通压缩 DMG
if command -v dmgbuild >/dev/null 2>&1; then
  : # dmgbuild 存在但配置/背景缺失，继续 fallback
else
  echo "==> dmgbuild 未安装，使用普通 hdiutil 压缩 DMG（如需精美安装盘请运行：pip install dmgbuild）"
fi

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"

echo "==> 拷贝 app 与应用程序快捷方式"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> 生成压缩 DMG"
hdiutil create -volname "$VOL" -srcfolder "$STAGE" -ov -format UDZO -imagekey zlib-level=9 "$DMG"

echo "==> 完成："
ls -la "$DMG"
echo ""
echo "使用：双击 $DMG 挂载，把 GameCenter.app 拖到 Applications 即可。"
echo "若打开时提示“已损坏/无法验证”，在终端执行一次："
echo "  xattr -dr com.apple.quarantine /Applications/GameCenter.app"
