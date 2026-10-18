import AppKit
import Foundation
import Observation
import SwiftUI

/// 一个正在运行的游戏实例（在 @MainActor 内创建与管理）
@MainActor
final class RunningInstance {
    let gameId: String
    var process: Process?        // .jar / .exe
    var runningApp: NSRunningApplication?  // .app
    init(gameId: String, process: Process?, runningApp: NSRunningApplication?) {
        self.gameId = gameId
        self.process = process
        self.runningApp = runningApp
    }
}

/// 全局可观察模型：持有游戏列表与界面状态。
/// 用 @Observable（Observation 宏，已可用）替代 @State（SwiftUIMacros 在本机 CLT SDK 缺失）。
@MainActor
@Observable
final class AppModel {
    var games: [GameRecord] = []
    var search: String = ""
    var selected: GameRecord?
    var groupBy: String = "none"   // none / type / name
    var viewMode: String = "list"  // list / grid（仅 UI 用，不影响业务逻辑）
    var importMessage: String?
    var errorMessage: String = ""
    var showError = false

    // 导入进度
    var isImporting = false
    var importTotal = 0
    var importCurrent = 0
    var importName = ""
    var importProgress: Double = 0

    // 启动 / 运行
    var launchingId: String?
    private var launchTask: Task<Void, Never>?
    var running: [String: RunningInstance] = [:]

    func reload() {
        games = GameStore.shared.load()
        if let sel = selected, let refreshed = games.first(where: { $0.id == sel.id }) {
            selected = refreshed
        } else if selected != nil {
            selected = nil
        }
    }

    func importGames() {
        let urls = GameImporter.presentImportPanel()
        importURLs(urls)
    }

    /// 从外部（拖拽）导入一组 URL，仅接受 .app/.jar/.exe
    func importURLs(_ urls: [URL]) {
        let valid = urls.filter { ["app", "jar", "exe"].contains($0.pathExtension.lowercased()) }
        guard !valid.isEmpty else {
            importMessage = "拖入的文件不是 .app / .jar / .exe，已忽略。"
            return
        }
        Task { await performImport(valid) }
    }

    private func performImport(_ urls: [URL]) async {
        isImporting = true
        importTotal = urls.count
        importCurrent = 0
        importProgress = 0
        var existing = games
        var added = 0
        for url in urls {
            if existing.contains(where: { $0.sourcePath == url.path }) { continue }
            let (name, type) = GameImporter.parse(url)
            importCurrent += 1
            importName = name
            importProgress = 0
            let id = UUID().uuidString
            let dest = GameStore.shared.folderURL(for: id).appendingPathComponent(url.lastPathComponent)
            for await frac in copyWithProgress(source: url, destination: dest) {
                importProgress = frac
            }
            let steamAppId = GameImporter.detectSteamAppId(sourcePath: url.path)
            let rec = GameRecord(id: id, name: name, type: type,
                                 sourcePath: url.path, libraryPath: dest.path,
                                 steamAppId: steamAppId, addedAt: Date())
            existing.append(rec)
            added += 1
        }
        games = existing
        GameStore.shared.save(games)
        if added > 0 { selected = existing.last }
        isImporting = false
        importMessage = added > 0 ? "已导入 \(added) 个游戏到资源库。" : "这些游戏已存在，未重复添加。"
        reload()
    }

    /// 启动游戏：先进入「正在启动」状态（可取消），再真正拉起，并登记运行实例。
    func launch(_ game: GameRecord) {
        guard launchingId == nil else { return }
        launchingId = game.id
        launchTask = Task { @MainActor in
            do {
                // 给一个短暂的「正在启动」窗口，模仿 Steam，可在此期间取消
                try await Task.sleep(nanoseconds: 600_000_000)
                if Task.isCancelled { launchingId = nil; return }
                let inst = try await GameLauncher.start(game)
                running[game.id] = inst
                launchingId = nil
                observe(inst)
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                    showError = true
                }
                launchingId = nil
            }
        }
    }

    /// 取消正在进行的启动
    func cancelLaunch() {
        launchTask?.cancel()
        launchingId = nil
    }

    /// 停止正在运行的游戏
    func stop(_ game: GameRecord) {
        if let inst = running[game.id] {
            inst.process?.terminate()
            inst.runningApp?.terminate()
            running.removeValue(forKey: game.id)
        }
    }

    /// 轮询检测游戏是否已退出，退出后从运行表移除
    private func observe(_ inst: RunningInstance) {
        Task { @MainActor in
            if let p = inst.process {
                while p.isRunning {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            } else if let a = inst.runningApp {
                while !a.isTerminated {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                }
            }
            self.running.removeValue(forKey: inst.gameId)
        }
    }

    func remove(_ game: GameRecord) {
        GameStore.shared.remove(id: game.id)
        running.removeValue(forKey: game.id)
        if selected?.id == game.id { selected = nil }
        reload()
    }

    static let shared = AppModel()
}
