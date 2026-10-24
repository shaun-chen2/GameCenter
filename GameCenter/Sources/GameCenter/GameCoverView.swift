import SwiftUI
import UniformTypeIdentifiers

/// 统一的封面组件：若游戏设置了自定义图标则直接展示，否则复用系统图标并叠加霓虹渐变底。
struct GameCoverView: View {
    let game: GameRecord

    var hasCustomIcon: Bool {
        game.iconPath.map { NSImage(contentsOf: URL(fileURLWithPath: $0)) != nil } ?? false
    }

    var body: some View {
        GameIcon(game: game)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(3 / 4, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.gcLine, lineWidth: 1)
            )
            .background {
                if hasCustomIcon {
                    Color.clear
                } else {
                    LinearGradient(
                        colors: [Color.gcAccent.opacity(0.28), Color.gcAccent2.opacity(0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
    }
}

/// 网格模式下的封面卡片：3:4 封面 + 名称 + 类型徽章 + 运行中绿点。
struct GameCoverCard: View {
    let game: GameRecord
    var model: AppModel

    var isRunning: Bool { model.running[game.id] != nil }
    var isLaunching: Bool { model.launchingId == game.id }
    var isSelected: Bool { model.selected?.id == game.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GameCoverView(game: game)
                .frame(maxWidth: .infinity)
                .aspectRatio(3 / 4, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.gcLine, lineWidth: 1)
                )

            HStack(spacing: 6) {
                if isLaunching {
                    ProgressView().controlSize(.small)
                } else if isRunning {
                    Circle().fill(Color.gcGreen).frame(width: 8, height: 8)
                        .shadow(color: Color.gcGreen, radius: 3)
                }
                Text(game.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.gcText)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            Text(game.type)
                .font(.caption)
                .foregroundStyle(Color.gcMuted)
                .lineLimit(1)
        }
        .padding(10)
        .background(Color.gcCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            Group {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.gcAccent : Color.gcLine, lineWidth: isSelected ? 2 : 1)
            }
        )
        .shadow(color: .black.opacity(isSelected ? 0.4 : 0.25), radius: isSelected ? 10 : 6, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            model.handleIconDrop(providers, for: game)
        }
    }
}
