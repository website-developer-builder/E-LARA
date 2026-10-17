import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if !model.hasFolders {
            WelcomeView()
        } else if model.items.isEmpty {
            ContentUnavailableView {
                Label("No media found yet", systemImage: "square.grid.2x2")
            } description: {
                Text("Your folders don't contain any supported photos, videos, or music. Try adding another folder, or check Settings for supported formats.")
            } actions: {
                Button("Add Folder…") { model.addFolders() }
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("Your library")
                        .font(.largeTitle.weight(.semibold))
                    QuickAccessRow()
                    let played = LibraryQuery.recentlyPlayed(model.items)
                    if !played.isEmpty {
                        HomeShelf(title: "Recently Played", items: played)
                    }
                    HomeShelf(title: "Recently Added", items: LibraryQuery.recentlyAdded(model.items))
                }
                .padding(24)
            }
        }
    }
}

/// Big, friendly shortcuts to Photos / Videos / Music with counts.
struct QuickAccessRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 14) {
            ForEach([SidebarSection.photos, .videos, .music]) { section in
                Button {
                    model.section = section
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: section.symbolName)
                            .font(.title2)
                            .foregroundStyle(.tint)
                            .frame(width: 32)
                        VStack(alignment: .leading) {
                            Text(section.title).font(.headline)
                            Text("\(model.count(for: section).formatted()) items")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(section.title), \(model.count(for: section)) items")
            }
        }
    }
}

struct HomeShelf: View {
    @Environment(AppModel.self) private var model
    let title: String
    let items: [MediaItem]

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.weight(.semibold))
            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                ForEach(items) { item in
                    MediaCardView(item: item, isSelected: model.selectedItemID == item.id)
                }
            }
        }
    }
}
