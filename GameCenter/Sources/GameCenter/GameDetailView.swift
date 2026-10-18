import AppKit
import SwiftUI

struct GameDetailView: View {
    var model: AppModel
    var game: GameRecord

    var isLaunching: Bool { model.launchingId == game.id }
    var isRunning: Bool { model.running[game.id] != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 英雄卡：大封面 + 标题 + 徽章 + 添加日期
                HStack(alignment: .top, spacing: 18) {
                    GameCoverView(game: game)
                        .frame(width: 132, height: 176)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.gcLine, lineWidth: 1)
                        )
                        .shadow(color: Color.gcAccent.opacity(0.25), radius: 14, y: 6)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(game.name)
                            .font(.title.bold())
                            .foregroundStyle(Color.gcText)
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            typeBadge(game.type)
                            if isRunning {
                                runningPill
                            }
                        }

                        Text("添加于 \(shortDate(game.addedAt))")
                            .font(.caption)
                            .foregroundStyle(Color.gcMuted)

                        Spacer(minLength: 0)
                    }

                    Spacer(minLength: 0)
                }
                .padding(18)
                .background(Color.gcCard)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.gcLine, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 12, y: 6)

                // 主要操作区
                HStack(spacing: 10) {
                    if isLaunching {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("正在启动…").font(.subheadline).foregroundStyle(Color.gcText)
                            Button("取消", role: .destructive) { model.cancelLaunch() }
                        }
                        .controlSize(.large)
                    } else if isRunning {
                        Button { model.stop(game) } label: {
                            Label("停止 ■", systemImage: "stop.fill")
                                .font(.headline)
                                .padding(.horizontal, 18).padding(.vertical, 10)
                                .frame(minWidth: 120)
                        }
                        .tint(Color.gcRed)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    } else {
                        Button { model.launch(game) } label: {
                            Label("启动 ▶", systemImage: "play.fill")
                                .font(.headline)
                                .padding(.horizontal, 18).padding(.vertical, 10)
                                .frame(minWidth: 120)
                        }
                        .tint(Color.gcAccent)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }

                    Button { GameLauncher.openLibraryFolder(game) } label: {
                        Label("打开资源路径", systemImage: "folder")
                            .padding(.horizontal, 14).padding(.vertical, 10)
                    }
                    .tint(Color.gcMuted)
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Spacer(minLength: 0)

                    Button("移除", role: .destructive) { model.remove(game) }
                        .tint(Color.gcRed)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }

                // 来源 / 资源路径区块
                VStack(alignment: .leading, spacing: 12) {
                    metaBlock(title: "来源", value: game.sourcePath)
                    Divider().background(Color.gcLine)
                    metaBlock(title: "资源路径", value: game.libraryPath)
                }
                .padding(18)
                .background(Color.gcCard)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.gcLine, lineWidth: 1)
                )

                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gcBg)
    }

    // MARK: - 小组件

    private var runningPill: some View {
        Label("运行中", systemImage: "circle.fill")
            .font(.caption)
            .foregroundStyle(Color.gcGreen)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color.gcGreen.opacity(0.12))
            .clipShape(Capsule())
    }

    private func typeBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Color.gcMuted)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color.gcLine.opacity(0.6))
            .clipShape(Capsule())
    }

    private func metaBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(Color.gcMuted)
            Text(value)
                .textSelection(.enabled)
                .font(.caption)
                .foregroundStyle(Color.gcText)
        }
    }
}

/// 侧栏列表行：40px 圆角封面 + 名称 + 类型 + 运行中绿点。
struct GameRow: View {
    let game: GameRecord
    var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            GameIcon(path: game.libraryPath)
                .frame(width: 36, height: 36)
                .background(Color.gcLine.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(game.name).font(.headline).foregroundStyle(Color.gcText).lineLimit(1)
                Text(game.type).font(.caption).foregroundStyle(Color.gcMuted).lineLimit(1)
            }

            Spacer(minLength: 0)

            if model.launchingId == game.id {
                ProgressView().controlSize(.small)
            } else if model.running[game.id] != nil {
                Circle().fill(Color.gcGreen).frame(width: 9, height: 9)
                    .shadow(color: Color.gcGreen, radius: 3)
            }
        }
        .padding(.vertical, 4)
    }
}

/// 从 libraryPath 取系统图标的封面（沿用原实现，去掉固定尺寸以支持灵活布局）。
struct GameIcon: View {
    let path: String

    var body: some View {
        Group {
            if let img = NSWorkspace.shared.icon(forFile: path) as NSImage? {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "gamecontroller")
            }
        }
    }
}

func shortDate(_ d: Date) -> String {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f.string(from: d)
}
