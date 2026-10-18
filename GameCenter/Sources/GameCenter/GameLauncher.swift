import AppKit
import Foundation

/// 启动器：按游戏类型选择启动方式。
/// - .app：NSWorkspace.openApplication（异步，可拿到 NSRunningApplication 以便停止）
/// - .jar：java -jar（Process）
/// - .exe：检测 Wine / CrossOver 后拉起；若未安装则自动下载 Gcenx 预编译 Wine 并解压（带进度）
@MainActor
final class GameLauncher {
    /// 本地自管理 Wine 安装目录（首次自动下载时写入）。
    static func wineInstallDir() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("GameCenter/wine", isDirectory: true)
    }

    /// 查找系统 / 路径 / CrossOver 中的 wine 可执行文件。
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

    /// 在本地自管理目录中递归查找 wine 可执行文件。
    private static func findWineBinary(in dir: URL) -> String? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: dir,
                                            includingPropertiesForKeys: [.isExecutableKey],
                                            options: [.skipsHiddenFiles]) else { return nil }
        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent == "wine" && fm.isExecutableFile(atPath: fileURL.path) {
                return fileURL.path
            }
        }
        return nil
    }

    /// 优先系统 / CrossOver，其次本地自管理目录。
    static func localWine() -> String? {
        if let w = findWine() { return w }
        return findWineBinary(in: wineInstallDir())
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

    /// 确保存在可用 wine：已安装则直接返回路径；否则下载并解压后返回。
    /// - parameter progress: 进度回调，参数为 (进度 0~1, 文字标签)。在主线程回调。
    static func ensureWine(progress: (@MainActor (Double, String) -> Void)? = nil) async throws -> String {
        // 1. 系统 / 路径 / CrossOver
        if let w = findWine() { return w }
        // 2. 本地自管理目录
        let dir = wineInstallDir()
        if let b = findWineBinary(in: dir) { return b }

        // 3. 需要下载
        progress?(0, "正在解析 Wine 下载源…")
        let url = try await resolveWineURL()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let tarball = dir.appendingPathComponent("wine-download.tar.xz")

        progress?(0.01, "正在下载 Wine…")
        try await downloadWine(from: url, to: tarball) { f in
            progress?(0.01 + f * 0.84, "正在下载 Wine…")
        }

        progress?(0.86, "正在解压 Wine…")
        try extractTarXZ(tarball, into: dir)
        try? FileManager.default.removeItem(at: tarball)

        guard let b = findWineBinary(in: dir) else {
            throw NSError(domain: "GameLauncher", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Wine 已下载，但未能在解压目录中找到可执行文件。"])
        }
        return b
    }

    /// 解析最新 Wine 预编译包下载地址（Gcenx/macOS_Wine_builds），失败回退到固定版本。
    static func resolveWineURL() async throws -> URL {
        let fallback = URL(string: "https://github.com/Gcenx/macOS_Wine_builds/releases/download/10.0/wine-stable-10.0-osx64.tar.xz")!
        do {
            let api = URL(string: "https://api.github.com/repos/Gcenx/macOS_Wine_builds/releases")!
            var req = URLRequest(url: api)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, _) = try await URLSession.shared.data(for: req)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                for release in json {
                    guard let assets = release["assets"] as? [[String: Any]] else { continue }
                    for a in assets {
                        if let name = a["name"] as? String,
                           name.hasPrefix("wine-stable-"), name.hasSuffix("osx64.tar.xz"),
                           let urlStr = a["browser_download_url"] as? String,
                           let u = URL(string: urlStr) {
                            return u
                        }
                    }
                }
            }
        } catch {
            // 网络失败时回退到固定版本
        }
        return fallback
    }

    /// 下载 Wine 压缩包到 dest，并通过 delegate 上报进度。
    static func downloadWine(from url: URL, to dest: URL, progress: (@MainActor (Double) -> Void)? = nil) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let delegate = WineDownloadDelegate(
                dest: dest,
                onProgress: { frac in Task { @MainActor in progress?(frac) } },
                onComplete: { result in cont.resume(with: result) }
            )
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            session.downloadTask(with: url).resume()
        }
    }

    /// 用系统 tar 解压 .tar.xz。
    static func extractTarXZ(_ archive: URL, into dir: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xJf", archive.path, "-C", dir.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "GameLauncher", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "解压 Wine 失败（tar 退出码 \(process.terminationStatus)）。"])
        }
    }

    /// 启动游戏（资源库拷贝），返回运行实例；失败抛错。
    /// - parameter progress: 用于 .exe 启动前自动下载 Wine 的进度回调（可选）。
    @discardableResult
    static func start(_ game: GameRecord, progress: (@MainActor (Double, String) -> Void)? = nil) async throws -> RunningInstance {
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
            let wine = try await ensureWine(progress: progress)
            let p = Process()
            p.executableURL = URL(fileURLWithPath: wine)
            p.arguments = [path]
            // 让 wine 能找到自身的辅助工具，并使用 GameCenter 托管的 WINEPREFIX
            var env = ProcessInfo.processInfo.environment
            let wineBin = (URL(fileURLWithPath: wine).deletingLastPathComponent().path)
            env["PATH"] = wineBin + ":" + (env["PATH"] ?? "/usr/bin:/bin")
            let prefix = wineInstallDir().appendingPathComponent("prefix", isDirectory: true).path
            env["WINEPREFIX"] = prefix
            p.environment = env
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

/// 下载进度 / 完成委托（在后台队列回调，仅通过主线程桥接更新 UI）。
/// 注意：URLSession 会在 didFinishDownloadingTo 返回后删除临时文件，因此必须在该方法内立即移动到目标路径。
final class WineDownloadDelegate: NSObject, @unchecked Sendable, URLSessionDownloadDelegate {
    private let dest: URL
    private let onProgress: (Double) -> Void
    private let onComplete: (Result<Void, Error>) -> Void
    private var completed = false

    init(dest: URL,
         onProgress: @escaping (Double) -> Void,
         onComplete: @escaping (Result<Void, Error>) -> Void) {
        self.dest = dest
        self.onProgress = onProgress
        self.onComplete = onComplete
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            onProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        do {
            let fm = FileManager.default
            // 确保目标父目录存在；若目标文件已存在则先删除（避免重复下载时失败）
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: dest.path) {
                try fm.removeItem(at: dest)
            }
            try fm.moveItem(at: location, to: dest)
            complete(.success(()))
        } catch {
            complete(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer { session.invalidateAndCancel() }
        if let error {
            complete(.failure(error))
        }
    }

    private func complete(_ result: Result<Void, Error>) {
        guard !completed else { return }
        completed = true
        onComplete(result)
    }
}
