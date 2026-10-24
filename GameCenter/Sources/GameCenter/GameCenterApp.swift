import AppKit
import SwiftUI

@main
struct GameCenterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let model = AppModel.shared

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 760, minHeight: 520)
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 关闭最后一个窗口即退出应用（macOS 版行为）
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
