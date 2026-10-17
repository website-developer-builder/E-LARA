import SwiftUI

@main
struct MediaHubApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup(AppConfig.appName) {
            ContentView()
                .environment(model)
                .frame(minWidth: 820, minHeight: 520)
        }
        .defaultSize(width: 1180, height: 760)
        .commands { AppCommands(model: model) }
    }
}

/// Menu bar commands and keyboard shortcuts.
struct AppCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Add Folder…") { model.addFolders() }
                .keyboardShortcut("o", modifiers: .command)
        }
        CommandGroup(after: .textEditing) {
            Button("Find…") { WindowHelpers.focusSearchField() }
                .keyboardShortcut("f", modifiers: .command)
        }
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { model.section = .settings }
                .keyboardShortcut(",", modifiers: .command)
        }
        CommandMenu("Controls") {
            Button(model.playback.isPlaying ? "Pause" : "Play") { model.playback.togglePlayPause() }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(model.playback.current == nil)
            Button("Next Song") { model.playback.next() }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
                .disabled(!model.playback.hasNext)
            Button("Previous Song") { model.playback.previous() }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
                .disabled(model.playback.current == nil)
            Divider()
            Button("Open Selected Item") { if let item = model.selectedItem { model.open(item) } }
                .disabled(model.selectedItem == nil)
            Button(model.selectedItem?.isFavorite == true ? "Remove from Favorites" : "Add to Favorites") {
                if let item = model.selectedItem { model.toggleFavorite(item) }
            }
            .keyboardShortcut("l", modifiers: .command)
            .disabled(model.selectedItem == nil)
            Button("Show in Finder") { if let item = model.selectedItem { model.showInFinder(item) } }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(model.selectedItem == nil)
        }
        CommandMenu("Library") {
            Button("Rescan All Folders") { model.rescanAll() }
                .keyboardShortcut("r", modifiers: .command)
            Divider()
            // ⌘1…⌘6 jump to sidebar sections.
            ForEach(Array(SidebarSection.allCases.dropLast().enumerated()), id: \.element) { index, section in
                Button(section.title) { model.section = section }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
        }
    }
}
