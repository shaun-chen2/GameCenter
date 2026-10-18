# GameCenter · 跨平台游戏启动器

> 统一管理并一键启动你本地的各类游戏：macOS 原生版（SwiftUI）+ Windows 版（Electron），统一深色「游戏启动器」风格。
>
> A cross-platform game launcher that manages and launches your local games from one place — a native macOS app (SwiftUI) and a Windows app (Electron), sharing one dark "game launcher" look.

---

## 功能特性 / Features

- **多类型游戏**：支持启动 `exe` / `jar` / 应用（`macOS .app`）/ 快捷方式（`.lnk`）/ 网页快捷方式（`.url`）。
  Launch `exe` / `jar` / apps (macOS `.app`) / shortcuts (`.lnk`) / web shortcuts (`.url`).
- **Steam 游戏**：自动识别 Steam App ID，通过 `steam://run/<id>` 或 `steam.exe -applaunch` 拉起（需本机装有 Steam 客户端）。
  Steam titles are auto-detected by App ID and launched via `steam://run/<id>` / `steam.exe -applaunch` (Steam client required).
- **导入方式**：面板导入 + 拖拽导入（`macOS` 版支持把文件拖进窗口）。
  Import via dialog or drag-and-drop (drag supported on macOS).
- **深色游戏风 UI**：封面网格 / 列表双视图、英雄详情卡、运行中状态指示。
  Dark game-launcher UI: cover-grid / list views, hero detail card, running-status indicator.
- **分组与搜索**：按类型 / 名称首字母分组，实时搜索。
  Group by type / initial, with live search.

---

## 目录结构 / Project Structure

```
GameCenter/        # macOS 版（SwiftUI，SwiftPM）
GameCenterWin/     # Windows 版（Electron）
ui-preview.html     # 纯静态界面预览（浏览器打开即可看效果，无需环境）
GameCenter/GameCenter.dmg              # macOS 安装包
GameCenterWin/dist/GameCenter 1.0.0.exe # Windows 安装包（portable）
```

---

## macOS 版（SwiftUI） / macOS version

### 构建 / Build

前置要求 / Prerequisites: Xcode Command Line Tools（`xcode-select --install`）。仅需 CLT，无需完整 Xcode。
Requires Xcode Command Line Tools only (full Xcode not needed).

```bash
cd GameCenter
swift build -c release --disable-sandbox
# 产物：.build/release/GameCenter
```

打包为 `.app` / Package into `.app`:

```bash
cp .build/release/GameCenter GameCenter.app/Contents/MacOS/GameCenter
# 或生成 DMG： / or build a DMG:
./make-dmg.sh
```

> 注：本项目刻意只用 `@Observable`（不依赖 SwiftUIMacros），因此在仅有 Command Line Tools 的环境也能编译。
> Note: the app intentionally uses `@Observable` only (no SwiftUIMacros), so it compiles under Command Line Tools alone.

### 运行 / Run

```bash
open GameCenter.app
# 未签名应用首次打开会被 Gatekeeper 拦截，去掉隔离属性即可：
# Unsigned apps are blocked by Gatekeeper on first launch; clear the quarantine attribute:
xattr -dr com.apple.quarantine GameCenter.app
```

也可直接运行命令行二进制 / Or run the binary directly: `./.build/release/GameCenter`

---

## Windows 版（Electron） / Windows version

### 构建 / Build

前置要求 / Prerequisites: Node.js 18+。

```bash
cd GameCenterWin
npm install
npm start            # 开发预览 / dev preview
npm run dist         # 打包 portable exe → dist/GameCenter 1.0.0.exe
```

> 打包配置中 `asar: false`（Electron 端资源以解包形式读取，改完前端文件无需重新打包即可生效）。
> The build sets `asar: false` so the frontend is unpacked — editing web files takes effect without rebuilding.

### 运行 / Run

- 开发： `npm start`
- 分发： 双击 `dist/GameCenter 1.0.0.exe`（未签名，Windows SmartScreen 可能拦截，按提示「仍要运行」即可）。
- Dev: `npm start`. Distribute: run `dist/GameCenter 1.0.0.exe` (unsigned — SmartScreen may warn; choose "Run anyway").

---

## 安装包 / Installers

仓库内已包含可直接下载的安装包 / Installers are committed in the repo:

- macOS：`GameCenter/GameCenter.dmg`
- Windows：`GameCenterWin/dist/GameCenter 1.0.0.exe`

> Windows 安装包约 68MB，超过 GitHub 推荐单文件 50MB，推送时仅警告、不影响使用；后续大安装包建议走 GitHub Releases。
> The Windows installer is ~68MB (> GitHub's 50MB recommended limit, warning only). For future large binaries, prefer GitHub Releases.

---

## 许可证 / License

MIT © chenhehe
