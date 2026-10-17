import SwiftUI

/// Main window: sidebar on the left, the selected section on the right.
struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 280)
        } detail: {
            DetailView()
                .toolbar { LibraryToolbar() }
                .inspector(isPresented: $model.showInspector) {
                    DetailsView()
                        .inspectorColumnWidth(min: 240, ideal: 290, max: 380)
                }
        }
        .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search all media")
        // Drop folders from Finder onto the window to add them.
        .dropDestination(for: URL.self) { urls, _ in
            let folders = urls.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            guard !folders.isEmpty else { return false }
            Task { await model.add(folders) }
            return true
        }
        .task { await model.start() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            model.shutdown()
        }
        .alert(item: $model.alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message))
        }
    }
}

/// Picks what to show for the current sidebar section.
struct DetailView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let section = model.effectiveSection
        Group {
            if let error = model.libraryError {
                ContentUnavailableView {
                    Label("Your library couldn't be opened", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else if !model.isLoaded {
                ProgressView("Opening your library…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
            switch section {
            case .home:
                HomeView()
            case .settings:
                SettingsView()
            default:
                LibraryView(section: section)
            }
            }
        }
        // While the viewer is open, VoiceOver should only see the viewer.
        .accessibilityHidden(model.viewerItem != nil)
        .overlay {
            if let item = model.quickViewItem, model.viewerItem == nil {
                QuickViewOverlay(item: item)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.easeOut(duration: 0.12), value: model.isQuickViewOpen)
        .onChange(of: model.searchText) { model.closeQuickView() }
        .overlay {
            if let item = model.viewerItem {
                MediaViewer(item: item)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: model.viewerItemID)
        .safeAreaInset(edge: .bottom, spacing: 0) { MiniPlayerView() }
        .navigationTitle(section.title)
    }
}

struct LibraryToolbar: ToolbarContent {
    @Environment(AppModel.self) private var model

    var body: some ToolbarContent {
        @Bindable var model = model
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                model.addFolders()
            } label: {
                Label("Add Folder", systemImage: "folder.badge.plus")
            }
            .help("Add a folder to your library (⌘O)")

            Button {
                model.rescanAll()
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .help("Look for new or changed files (⌘R)")
            .disabled(!model.hasFolders || model.isScanning)

            if model.effectiveSection != .settings {
                Menu {
                    Picker("Sort By", selection: $model.sort) {
                        ForEach(LibrarySort.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Sort: \(model.sort.title)", systemImage: "arrow.up.arrow.down")
                }
                .help("Sort: \(model.sort.title)")

                Picker("View", selection: $model.viewMode) {
                    Label("Grid", systemImage: "square.grid.2x2").tag(ViewMode.grid)
                    Label("List", systemImage: "list.bullet").tag(ViewMode.list)
                }
                .pickerStyle(.segmented)
                .help("Switch between grid and list")

                Button {
                    model.showInspector.toggle()
                } label: {
                    Label("Info", systemImage: "info.circle")
                }
                .keyboardShortcut("i", modifiers: .command)
                .help("Show details for the selected item (⌘I)")
            }
        }
    }
}
