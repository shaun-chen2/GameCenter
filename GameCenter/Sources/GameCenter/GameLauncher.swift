import AppKit
import Foundation

/// 启动器：按游戏类型选择启动方式。
/// - .app：NSWorkspace.openApplication（异步，可拿到 NSRunningApplication 以便停止）
/// - .jar：java -jar（Process）
/// - .exe：检测 Wine / CrossOver 后拉起（Process）
@MainActor
final class GameLauncher {
    /// 查找 wine 可执行文件（含 CrossOver）
    static func findWine() -> String? {
        let candidates = [
            "/opt/homebrew/bin/wine",
            "/usr/local/bin/wine",
            "/usr/bin/wine",
            "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/CrossOver.app/Contents/MacOS/CrossOver"
        ]
        for c in candidates where FileManager.default.isExecutableFile(atPath: c) {
            return c
        }
        return wineInPath()
    }

    private static func wineInPath() -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        p.arguments = ["wine"]
        let pipe = Pipe()
        p.standardOutput = pipe
        try? p.run()
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty else { return nil }
        return s
    }

    /// 启动游戏（资源库拷贝），返回运行实例；失败抛错。
    @discardableResult
    static func start(_ game: GameRecord) async throws -> RunningInstance {
        let path = game.libraryPath
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "app":
            // Steam 游戏：用 steam://run/<appid> 启动（老数据未记录时从 sourcePath 回退检测）
            let steamId = game.steamAppId ?? GameImporter.detectSteamAppId(sourcePath: game.sourcePath)
            if let steamId, !steamId.isEmpty,
               let url = URL(string: "steam://run/\(steamId)") {
                let ok = NSWorkspace.shared.open(url)
                if !ok {
                    throw NSError(domain: "GameLauncher", code: 0,
                                  userInfo: [NSLocalizedDescriptionKey: "无法打开 Steam 启动链接（steam://run/\(steamId)）。请确认 Steam 已安装。"])
                }
                // Steam 协议启动后无法直接追踪运行状态，返回空实例
                return RunningInstance(gameId: game.id, process: nil, runningApp: nil)
            }
            let url = URL(fileURLWithPath: path)
            let cfg = NSWorkspace.OpenConfiguration()
            let app = try await NSWorkspace.shared.openApplication(at: url, configuration: cfg)
            return RunningInstance(gameId: game.id, process: nil, runningApp: app)
        case "jar":
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/java")
            p.arguments = ["-jar", path]
            try p.run()
            return RunningInstance(gameId: game.id, process: p, runningApp: nil)
        case "exe":
            guard let wine = findWine() else {
                throw NSError(domain: "GameLauncher", code: 0,
                              userInfo: [NSLocalizedDescriptionKey: "未检测到 Wine。请先安装 Wine（brew install --cask wine-stable）或 CrossOver，再启动 .exe 游戏。"])
            }
            let p = Process()
            p.executableURL = URL(fileURLWithPath: wine)
            p.arguments = [path]
            try p.run()
            return RunningInstance(gameId: game.id, process: p, runningApp: nil)
        default:
            throw NSError(domain: "GameLauncher", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "不支持的格式：\(ext)"])
        }
    }

    /// 在访达中打开游戏的资源文件夹（Games/<id>/），即拷贝后所在目录
    static func openLibraryFolder(_ game: GameRecord) {
        let url = GameStore.shared.folderURL(for: game.id)
        NSWorkspace.shared.open(url)
    }
}
