import SwiftUI

/// Grid or list of media for a sidebar section (All Media, Photos, Videos, Music, Favorites).
struct LibraryView: View {
    @Environment(AppModel.self) private var model
    let section: SidebarSection

    var body: some View {
        let results = model.results(for: section)
        VStack(spacing: 0) {
            SectionHeader(section: section, count: results.count)
            Divider()
            if results.isEmpty {
                LibraryEmptyState(section: section)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.viewMode == .grid {
                MediaGridView(items: results)
            } else {
                MediaListView(items: results)
            }
        }
    }
}

struct SectionHeader: View {
    @Environment(AppModel.self) private var model
    let section: SidebarSection
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.isSearching ? "Search Results" : section.title)
                    .font(.title2.weight(.semibold))
                Text(model.isSearching
                     ? "Matching “\(LibraryQuery.normalized(model.searchText))” in \(section.title)"
                     : section.subtitle)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.hasFolders {
                Text("\(count.formatted()) \(count == 1 ? "item" : "items") · \(model.sort.title)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

/// Lazy thumbnail grid — only visible cards are created.
/// Keyboard: arrows move the selection, Return opens, Space plays/pauses music.
struct MediaGridView: View {
    @Environment(AppModel.self) private var model
    let items: [MediaItem]

    private let minCardWidth: CGFloat = 160
    private let spacing: CGFloat = 16
    private let padding: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            let columnCount = max(1, Int((geo.size.width - padding * 2 + spacing) / (minCardWidth + spacing)))
            let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: columnCount)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(items) { item in
                            MediaCardView(item: item, isSelected: model.selectedItemID == item.id)
                                .id(item.id)
                        }
                    }
                    .padding(padding)
                }
                .focusable()
                .focusEffectDisabled()
                .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in
                    let step: Int = switch press.key {
                    case .leftArrow: -1
                    case .rightArrow: 1
                    case .upArrow: -columnCount
                    default: columnCount
                    }
                    moveSelection(by: step, proxy: proxy)
                    return .handled
                }
                .onKeyPress(.return) {
                    guard let item = model.selectedItem else { return .ignored }
                    model.open(item)
                    return .handled
                }
                .onKeyPress(.space) {
                    guard model.playback.current != nil else { return .ignored }
                    model.playback.togglePlayPause()
                    return .handled
                }
            }
        }
    }

    private func moveSelection(by step: Int, proxy: ScrollViewProxy) {
        guard !items.isEmpty else { return }
        let current = items.firstIndex { $0.id == model.selectedItemID }
        let next = current.map { min(max($0 + step, 0), items.count - 1) } ?? 0
        model.selectedItemID = items[next].id
        proxy.scrollTo(items[next].id)
    }
}

/// Compact list, handy for music.
struct MediaListView: View {
    @Environment(AppModel.self) private var model
    let items: [MediaItem]

    var body: some View {
        let selection = Binding<MediaItem.ID?>(
            get: { model.selectedItemID },
            set: { model.selectedItemID = $0 }
        )
        List(selection: selection) {
            ForEach(items) { item in
                MediaRowView(item: item)
                    .tag(item.id)
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: MediaItem.ID.self) { ids in
            if let id = ids.first, let item = items.first(where: { $0.id == id }) {
                MediaContextMenu(item: item)
            }
        } primaryAction: { ids in
            if let id = ids.first, let item = items.first(where: { $0.id == id }) { model.open(item) }
        }
    }
}
