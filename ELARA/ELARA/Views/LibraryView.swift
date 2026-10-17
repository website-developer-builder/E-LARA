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
/// Keyboard: arrows move the selection, Return opens, Space = Quick View (hold to peek).
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
                .mediaKeyboard(items: items, verticalStep: columnCount) { id in
                    withAnimation(.easeInOut(duration: 0.15)) { proxy.scrollTo(id) }
                }
            }
        }
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
        // List already moves the selection with ↑ ↓ and has its own focus;
        // add ← → (previous/next), Space (Quick View), Return, and Esc.
        .mediaKeyboard(items: items, verticalStep: nil, makeFocusable: false)
        .contextMenu(forSelectionType: MediaItem.ID.self) { ids in
            if let id = ids.first, let item = items.first(where: { $0.id == id }) {
                MediaContextMenu(item: item)
            }
        } primaryAction: { ids in
            if let id = ids.first, let item = items.first(where: { $0.id == id }) { model.open(item) }
        }
    }
}
