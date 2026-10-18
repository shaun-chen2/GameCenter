import os
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    var model: AppModel

    var filtered: [GameRecord] {
        let q = model.search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return model.games }
        return model.games.filter { $0.name.lowercased().contains(q) || $0.type.lowercased().contains(q) }
    }

    /// 按类型 / 名称首字母分组（搜索之后再做，仅列表模式使用）
    var groups: [(key: String, items: [GameRecord])] {
        let list = filtered
        let dict = Dictionary(grouping: list) { (game: GameRecord) -> String in
            if model.groupBy == "type" { return game.type }
            return String((game.name.uppercased().first ?? "#"))
        }
        return dict.sorted { $0.key < $1.key }
            .map { (key: $0.key, items: $0.value.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }) }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailArea
        }
        .background(Color.gcBg)
        .toolbar { toolbarContent }
        .alert("导入结果",
               isPresented: Binding(get: { model.importMessage != nil },
                                    set: { if !$0 { model.importMessage = nil } })) {
            Button("好") {}
        } message: { Text(model.importMessage ?? "") }
        .alert("错误",
               isPresented: Binding(get: { model.showError },
                                    set: { model.showError = $0 })) {
            Button("好") {}
        } message: { Text(model.errorMessage) }
        .onAppear { model.reload() }
    }

    // MARK: - 详情区（英雄详情 / 空状态）

    private var detailArea: some View {
        Group {
            if let sel = model.selected {
                GameDetailView(model: model, game: sel)
            } else {
                emptyView
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.gcMuted)
            Text("从左侧选择或导入一个游戏")
                .font(.headline)
                .foregroundStyle(Color.gcMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gcBg)
    }

    // MARK: - 侧栏（列表 / 网格 双模式）

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("游戏库")
                    .font(.headline)
                    .foregroundStyle(Color.gcText)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 4)

            Picker("视图", selection: Binding(get: { model.viewMode }, set: { model.viewMode = $0 })) {
                Text("列表").tag("list")
                Text("网格").tag("grid")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 10).padding(.bottom, 8)

            Picker("分组", selection: Binding(get: { model.groupBy }, set: { model.groupBy = $0 })) {
                Text("无").tag("none")
                Text("类型").tag("type")
                Text("名称").tag("name")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 10).padding(.bottom, 8)

            TextField("搜索游戏",
                      text: Binding(get: { model.search }, set: { model.search = $0 }))
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 10).padding(.bottom, 8)

            if model.isImporting {
                VStack(alignment: .leading, spacing: 4) {
                    Text("正在导入 \(model.importName)（\(model.importCurrent)/\(model.importTotal)）")
                        .font(.caption)
                        .foregroundStyle(Color.gcMuted)
                    ProgressView(value: model.importProgress)
                        .controlSize(.small)
                        .tint(Color.gcAccent)
                }
                .padding(.horizontal, 10).padding(.bottom, 6)
            }

            if model.games.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(Color.gcMuted)
                    Text("暂无游戏，点击右上角「导入游戏」或拖入文件")
                        .font(.caption)
                        .foregroundStyle(Color.gcMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
            } else if model.viewMode == "grid" {
                // 网格模式：侧栏展示封面卡，选中即开详情，再次点按取消选中
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 110, maximum: 140), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(filtered) { game in
                            GameCoverCard(game: game, model: model)
                                .onTapGesture {
                                    if model.selected?.id == game.id {
                                        model.selected = nil
                                    } else {
                                        model.selected = game
                                    }
                                }
                        }
                    }
                    .padding(12)
                }
                .background(Color.gcSide)
            } else {
                // 列表模式：沿用原有分组列表 + 选中态
                List(selection: Binding(get: { model.selected }, set: { model.selected = $0 })) {
                    if model.groupBy == "none" {
                        ForEach(filtered) { game in
                            GameRow(game: game, model: model).tag(game)
                        }
                    } else {
                        ForEach(groups, id: \.key) { group in
                            Section(header: Text(group.key).foregroundStyle(Color.gcMuted)) {
                                ForEach(group.items) { game in
                                    GameRow(game: game, model: model).tag(game)
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.gcSide)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
            return true
        }
    }

    /// 解析拖入的 NSItemProvider，转为文件 URL 后交给模型导入
    private func handleDrop(_ providers: [NSItemProvider]) {
        let collected = OSAllocatedUnfairLock<[URL]>(initialState: [])
        let dg = DispatchGroup()
        for p in providers {
            guard p.hasItemConformingToTypeIdentifier("public.file-url") else { continue }
            dg.enter()
            p.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                defer { dg.leave() }
                var url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let u = item as? URL {
                    url = u
                }
                if let u = url { collected.withLock { $0.append(u) } }
            }
        }
        dg.notify(queue: .main) {
            model.importURLs(collected.withLock { $0 })
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Button(action: { model.importGames() }) { Label("导入游戏", systemImage: "plus") }
        }
    }
}
