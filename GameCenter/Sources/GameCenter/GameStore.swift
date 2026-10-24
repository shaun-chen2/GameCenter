import Foundation

struct GameRecord: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var type: String
    var sourcePath: String     // 原始导入位置（来源）
    var libraryPath: String    // 资源库中拷贝后的实际游戏路径（启动/图标使用）
    var steamAppId: String?    // 若检测为 Steam 游戏，记录 App ID，启动时走 steam://run/<id>
    var iconPath: String?     // 自定义图标（绝对路径）；为空则用系统图标
    var addedAt: Date
}

/// 轻量存储 + 资源库管理。
/// - games.json 保存游戏列表（Application Support/GameCenter/）
/// - Games/<id>/ 保存每个游戏拷贝过来的实际文件，启动的也是这份拷贝
final class GameStore: Sendable {
    static let shared = GameStore()
    let baseDir: URL
    let gamesDir: URL
    private let fileURL: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.baseDir = base.appendingPathComponent("GameCenter", isDirectory: true)
        self.gamesDir = baseDir.appendingPathComponent("Games", isDirectory: true)
        try? FileManager.default.createDirectory(at: gamesDir, withIntermediateDirectories: true)
        self.fileURL = baseDir.appendingPathComponent("games.json")
    }

    func load() -> [GameRecord] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([GameRecord].self, from: data)) ?? []
    }

    func save(_ games: [GameRecord]) {
        let enc = JSONEncoder()
        enc.outputFormatting = .prettyPrinted
        if let data = try? enc.encode(games) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func remove(id: String) {
        try? FileManager.default.removeItem(at: folderURL(for: id))
        save(load().filter { $0.id != id })
    }

    /// 某游戏在资源库中的文件夹（Games/<id>）
    func folderURL(for id: String) -> URL {
        gamesDir.appendingPathComponent(id, isDirectory: true)
    }

    /// 某游戏的自定义图标存放路径（Games/<id>/icon.<ext>）
    func iconURL(for id: String, ext: String) -> URL {
        folderURL(for: id).appendingPathComponent("icon").appendingPathExtension(ext)
    }
}
