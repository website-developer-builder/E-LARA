# Implementation Roadmap

Build in small verified milestones. Keep the app compiling at the end of each milestone.

## Milestone 0: Project setup
Deliver:
- Xcode project with correct macOS app target.
- App launches into a simple SwiftUI window.
- Basic folder structure and README.
- Deployment target and sandbox decision documented.
- Git repository recommended.

Exit criteria:
- Project builds and launches on the developer's Mac.
- No unnecessary third-party dependencies.

## Milestone 1: UI shell
Deliver:
- Sidebar and toolbar.
- Home, All Media, Photos, Videos, Music, Favorites, Settings screens.
- Consistent empty states.
- Search field and view controls wired to placeholder state.
- Light/Dark mode support.

Exit criteria:
- Navigation works; UI does not depend on real media yet.

## Milestone 2: Folder selection and indexing
Deliver:
- Add selected folder using native macOS panel.
- Permission/bookmark handling.
- Background scan with progress and cancellation.
- Extract media metadata and persist index.
- Avoid duplicate indexing for overlapping selected folders.
- Error and unavailable states.

Exit criteria:
- Can index a test folder with sample media and relaunch with saved library.

## Milestone 3: Search, grid, thumbnails
Deliver:
- Media grid and optional audio list.
- Asynchronous thumbnail generation and caching.
- Universal filename search.
- Type filters, sort, favorites, details panel.
- Show in Finder.

Exit criteria:
- All indexed test files can be found and inspected.

## Milestone 4: Preview and playback
Deliver:
- Photo preview.
- Audio mini-player.
- Video player.
- Playback error handling.
- Recent playback metadata if reliable.

Exit criteria:
- Supported test files open/play in-app and app remains responsive.

## Milestone 5: Reliability and polish
Deliver:
- Rescan and stale-entry reconciliation.
- Handle external drives and permission loss.
- Empty/loading/error states.
- Keyboard shortcuts and accessibility pass.
- Unit/UI tests.
- Performance pass with a large synthetic library.

Exit criteria:
- Acceptance checklist passes.

## Milestone 6: Packaging
Deliver:
- App icon placeholder or designed icon.
- Release build instructions.
- Version/build number.
- Signing/notarization guidance if distribution is planned.
- Known limitations and tested formats.

Exit criteria:
- A reproducible build process exists and the app has been tested outside the debug preview.

## Implementation rules
- Do not jump ahead while core project fails to build.
- Avoid giant source files; keep responsibilities separate.
- Add comments for non-obvious permission and concurrency logic.
- Use realistic test fixtures and document manual test steps.
- If an API depends on macOS version, check availability and document fallback.
