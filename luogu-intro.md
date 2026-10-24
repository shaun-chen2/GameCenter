# 游戏散落一硬盘？我写了个 GameCenter，把 .exe / .jar / .app 收进一个库

chenhehe

> 本文为个人项目介绍，采用洛谷专栏的排版气质撰写，与洛谷无任何隶属或合作关系。内容均为原创，未复制第三方文档。

前几年，为了玩上几个本地的小游戏，我的下载文件夹里慢慢堆满了各种 `.exe`、`.jar` 和散落的 `.app`。每次想再玩，都要翻半天目录、双击的时候还要祈祷 Wine 没掉链子。后来我就在想：Steam 能统一管理买来的游戏，那我这些散装游戏，为什么不能也有个「启动器」？

既然没有顺手的，不如自己写一个。考虑到 macOS 和 Windows 我都要用，我就做了 **GameCenter**——一个跨平台的本地游戏启动器，把散落各处的游戏收进一个库，点一下就启动。

## 什么是 GameCenter？

GameCenter 是一个跨平台（macOS 原生 SwiftUI + Windows Electron）的本地游戏启动器。

它的核心目标很简单：**统一管理你硬盘上的各类游戏**，支持 `exe` / `jar` / macOS `.app` / 快捷方式 `.lnk` / 网页快捷方式 `.url`，让你像在 Steam 里一样，一个列表里看到所有游戏、点一下就开。

## 核心功能特性

- **多类型游戏一把抓**：`exe`、`jar`、`macOS .app`、`.lnk`、`.url` 通吃，导入后统一进资源库。
- **Steam 一键启动**：自动识别 Steam App ID，通过 `steam://run/<id>` 唤起，省去手动找客户端。
- **.exe 自动装 Wine**：macOS 上没检测到 Wine / CrossOver 时，自动下载 Gcenx 预编译 Wine 并解压到本地，启动时显示「正在下载依赖（Wine）… X%」进度条，无需手动 `brew install`。
- **导入超方便**：面板导入 + 拖拽导入（macOS 版支持把文件直接拖进窗口）。
- **深色游戏风 UI**：封面网格 / 列表双视图、英雄详情卡、运行中状态指示，统一的两端视觉。
- **分组与搜索**：按类型 / 名称首字母分组，实时搜索，游戏一多也不乱。

## 快速上手

### 1. 安装

macOS 需要 Xcode Command Line Tools（`xcode-select --install`）：

```bash
cd GameCenter
swift build -c release --disable-sandbox
# 产物：.build/out/Products/Release/GameCenter（沙箱/CI 环境下路径含 /out/Products）
cp .build/out/Products/Release/GameCenter GameCenter.app/Contents/MacOS/GameCenter
open GameCenter.app
```

> 未签名应用首次打开可能被 Gatekeeper 拦截，去掉隔离属性即可：
> `xattr -dr com.apple.quarantine GameCenter.app`

Windows 需要 Node.js 18+：

```bash
cd GameCenterWin
npm install
npm start            # 开发预览
npm run dist         # 打包 portable exe → dist/GameCenter 1.0.0.exe
```

> 打包配置中 `asar: false`，改完前端文件无需重新打包即可生效。分发的 exe 未签名，Windows SmartScreen 可能拦截，按提示「仍要运行」即可。

### 2. 导入与启动

1. 点击「导入」，或在 macOS 上把游戏文件拖进窗口。
2. 游戏按 ID 分文件夹拷贝进资源库（原始文件不被改动），可随时在详情页「打开资源路径」查看。
3. 选中游戏，点「启动 ▶」即可；运行中会显示绿点，可随时「停止」。

## 关于 .exe 自动装 Wine 这件事

说实话，最开始我想直接用 `brew install wine-stable`，结果发现 Homebrew 的 `wine-stable` cask 自 2026-09-01 起，就因为过不了 macOS Gatekeeper 检查被官方禁用了。

既然 brew 走不通，就改走 Gcenx 的预编译包：从 GitHub（Gcenx/macOS_Wine_builds）拉取 `.tar.xz`，解压到 `~/Library/Application Support/GameCenter/wine`，解压即用。下载时界面会显示进度条，想反悔随时能取消；下载完成后自动配上正确的 `PATH` 和 `WINEPREFIX` 再启动游戏。

> 提示：Gcenx 的 Wine 需要 XQuartz 提供 X11 运行时，macOS 上请提前装好 XQuartz。

## 开源协议与致谢

GameCenter 采用 **MIT** 协议开源，欢迎下载、改玩、提建议。

- 源代码：<https://github.com/shaun-chen2/GameCenter>
- 安装包：仓库内含 `GameCenter.dmg`（macOS）与 `GameCenter 1.0.0.exe`（Windows）

感谢 SwiftUI、Electron，以及 Gcenx 维护的 macOS Wine 构建等开源生态，让这个小工具能站在一众巨人的肩膀上。

## 结语

项目已在 GitHub 开源：<https://github.com/shaun-chen2/GameCenter>，欢迎下载体验！

如果你的游戏也散落各处、每次找起来头疼，不妨试试 GameCenter，把它们在同一个列表里安个家。也欢迎大家试用、点个 Star，或者提出你的宝贵建议！
