import AppKit
import Foundation
import UniformTypeIdentifiers

struct GameImporter {
    /// 弹出文件选择面板，返回用户选择的游戏 URL（.app / .jar / .exe）
    @MainActor
    static func presentImportPanel() -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.title = "导入游戏"
        panel.message = "选择 .app（Steam/原生）、.jar（Java）或 .exe（Wine）文件"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [
            UTType(filenameExtension: "app")!,
            UTType(filenameExtension: "jar")!,
            UTType(filenameExtension: "exe")!
        ]
        guard panel.runModal() == .OK else { return [] }
        return panel.urls
    }

    /// 解析 URL 得到显示名与类型
    static func parse(_ url: URL) -> (name: String, type: String) {
        let ext = url.pathExtension.lowercased()
        let name = url.deletingPathExtension().lastPathComponent
        switch ext {
        case "app":
            return (bundleDisplayName(url) ?? name, "macOS App")
        case "jar":
            return (name, "Java")
        case "exe":
            return (name, "Windows (Wine)")
        default:
            return (name, ext.uppercased())
        }
    }

    /// 读取 .app 的 Info.plist 显示名
    static func bundleDisplayName(_ url: URL) -> String? {
        let infoURL = url.appendingPathComponent("Contents/Info.plist")
        guard let plist = NSDictionary(contentsOf: infoURL),
              let name = (plist["CFBundleDisplayName"] ?? plist["CFBundleName"]) as? String,
              !name.isEmpty else { return nil }
        return name
    }

    /// 检测该 .app 是否来自 Steam：从 steamapps/appmanifest_*.acf 中匹配 App ID。
    /// 若 sourcePath 不在 Steam 路径中（如从桌面拷贝导入），会回退搜索默认 Steam 库。
    static func detectSteamAppId(sourcePath: String) -> String? {
        let fm = FileManager.default
        let appName = URL(fileURLWithPath: sourcePath).deletingPathExtension().lastPathComponent

        // 1. 先尝试从 sourcePath 向上找到 steamapps
        var url = URL(fileURLWithPath: sourcePath)
        var steamappsURL: URL?
        for _ in 0..<10 {
            url = url.deletingLastPathComponent()
            if url.lastPathComponent == "steamapps" {
                steamappsURL = url
                break
            }
            if url.path == "/" { break }
        }

        // 2. 若 sourcePath 不在 steamapps 内，搜索默认 Steam 库
        if steamappsURL == nil {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let candidates = [
                home.appendingPathComponent("Library/Application Support/Steam/steamapps"),
            ]
            for c in candidates {
                if fm.fileExists(atPath: c.path) {
                    steamappsURL = c
                    break
                }
            }
        }

        guard let steamapps = steamappsURL,
              let manifests = try? fm.contentsOfDirectory(at: steamapps, includingPropertiesForKeys: nil)
            .filter({ $0.lastPathComponent.hasPrefix("appmanifest_") && $0.pathExtension == "acf" })
        else { return nil }

        // 被导入 .app 所在的 common 子文件夹名（如 "Euro Truck Simulator 2"）
        let commonDir = URL(fileURLWithPath: sourcePath).deletingLastPathComponent()
        let installDirName = commonDir.lastPathComponent

        for manifest in manifests {
            guard let text = try? String(contentsOf: manifest, encoding: .utf8) else { continue }
            let appid = extractACFValue(text, key: "appid")
            let installdir = extractACFValue(text, key: "installdir")
            let name = extractACFValue(text, key: "name")

            // 来源路径在 Steam 内时：匹配文件夹名 / 游戏名
            if installDirName.caseInsensitiveCompare("common") != .orderedSame {
                if installdir?.caseInsensitiveCompare(installDirName) == .orderedSame
                    || name?.caseInsensitiveCompare(installDirName) == .orderedSame {
                    return appid
                }
            }

            // 来源路径不在 Steam 内时（如桌面拷贝）：在 steamapps/common/<installdir> 下找同名 .app
            if let installdir {
                let candidateApp = steamapps
                    .appendingPathComponent("common", isDirectory: true)
                    .appendingPathComponent(installdir, isDirectory: true)
                    .appendingPathComponent(appName + ".app", isDirectory: true)
                if fm.fileExists(atPath: candidateApp.path) {
                    return appid
                }
            }
        }
        return nil
    }

    private static func extractACFValue(_ text: String, key: String) -> String? {
        let pattern = #""# + NSRegularExpression.escapedPattern(for: key) + #""\s+"([^"]*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) else { return nil }
        if let r = Range(match.range(at: 1), in: text) {
            return String(text[r])
        }
        return nil
    }
}
