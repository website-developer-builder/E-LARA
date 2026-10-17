# Decisions and Open Questions

## Decisions already made
- Build a native macOS application using SwiftUI.
- The app combines photos, videos, and music into one local library.
- The most important advantage is a simple, user-friendly experience.
- The user should not have to hunt through Finder to find media.
- Files should remain in their existing folders by default.
- The first version should be local-first and not require a server.
- The app name “MediaHub” is provisional.

## Sensible defaults for the MVP
- Use a native sidebar and grid.
- Search filenames across all indexed media.
- Ask the user to choose folders instead of scanning the whole disk.
- Support common formats based on actual native framework capabilities.
- Store metadata and thumbnails in app-owned storage, not the original media.
- Start with manual rescan and add automatic change monitoring later if needed.
- Use SwiftData if it fits the selected deployment target; otherwise select SQLite and document why.
- Support macOS Light/Dark appearance.
- Build for the user's Mac first; do not promise Windows/mobile support.

## Decisions Claude should document before implementation
1. Minimum macOS version.
2. Sandbox status and entitlement choices.
3. Persistence technology and migration strategy.
4. Thumbnail cache format, limits, and cleanup policy.
5. Which exact image/audio/video formats are verified on the selected OS.
6. How overlapping folder roots and file moves are reconciled.
7. Whether custom playlists/collections fit the first release or should be deferred.

## Do not block on
- Final app name or branding.
- Custom icon.
- Cloud features.
- AI-powered search.
- Distribution outside the developer's Mac.

Choose conservative defaults, document them, and keep the name easy to change.
