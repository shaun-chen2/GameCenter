#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "==> 编译中 (release) ..."
swift build -c release

BIN=".build/release/GameCenter"
APP="GameCenter.app"

echo "==> 打包 $APP ..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/GameCenter"

# App icon
ICON_SRC="Assets/AppIcon.icns"
if [[ -f "$ICON_SRC" ]]; then
    cp "$ICON_SRC" "$APP/Contents/Resources/AppIcon.icns"
fi

# 若有 Xcode（actool 可用），额外编译 asset catalog 得到 Assets.car，
# 让图标在 macOS 27 下与系统 app 完全一致；否则回退到上面的 icns。
if [[ -d "Assets.xcassets" ]] && command -v xcrun >/dev/null 2>&1 && xcrun -f actool >/dev/null 2>&1; then
    ACTOOL_OUT="$(mktemp -d)"
    if xcrun actool --compile "$ACTOOL_OUT" --platform macosx --minimum-deployment-target 14.0 --app-icon AppIcon Assets.xcassets >/dev/null 2>&1; then
        CAR_FILE="$(find "$ACTOOL_OUT" -name 'Assets.car' | head -1)"
        if [[ -n "$CAR_FILE" ]]; then
            cp "$CAR_FILE" "$APP/Contents/Resources/Assets.car"
            echo "==> 已编译 Assets.car（完整图标）"
        fi
    fi
    rm -rf "$ACTOOL_OUT"
fi

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>GameCenter</string>
    <key>CFBundleDisplayName</key><string>GameCenter</string>
    <key>CFBundleIdentifier</key><string>com.example.gamecenter</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>CFBundleExecutable</key><string>GameCenter</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIconName</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
EOF

echo "完成：双击 $APP 即可运行"
