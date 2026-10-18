import SwiftUI

/// 统一的封面组件：复用现有 `GameIcon`（从 libraryPath 取系统图标），
/// 背后叠加霓虹渐变底，并加圆角与细描边，用于详情英雄区与网格卡片。
struct GameCoverView: View {
    let game: GameRecord

    var body: some View {
        GameIcon(path: game.libraryPath)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(3 / 4, contentMode: .fill)
            .background(
                LinearGradient(
                    colors: [Color.gcAccent.opacity(0.28), Color.gcAccent2.opacity(0.14)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.gcLine, lineWidth: 1)
            )
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
    }
}
