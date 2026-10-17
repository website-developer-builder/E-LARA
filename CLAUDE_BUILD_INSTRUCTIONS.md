# Instructions for Claude: Build MediaHub

You are the lead macOS engineer implementing MediaHub from this specification. The user wants a real native macOS application built with SwiftUI, not just a mockup or a web app.

## First, read the project documents
Read every Markdown document in this pack before making architectural decisions. Treat `PRODUCT_REQUIREMENTS.md`, `UX_AND_UI_SPEC.md`, and `MEDIA_INDEXING_AND_PERMISSIONS.md` as primary requirements.

## Work style
1. Start by inspecting the current workspace and available Xcode/project files. Do not overwrite existing work without checking it.
2. If no Xcode project exists, create a native macOS SwiftUI project. If you cannot directly create or build the project in the current environment, provide exact steps and complete source files in a clear structure.
3. Implement one roadmap milestone at a time.
4. At the beginning of each milestone, state what you will build and which files will change.
5. After each milestone, build the project and run relevant tests when tools/environment permit.
6. Fix compiler errors before moving on.
7. Never claim that a build or test passed unless you actually ran it and observed the result.
8. Keep source code readable and split into logical files.
9. Do not introduce a web frontend, Electron, React Native, server, or cloud backend. This is a native SwiftUI Mac app.
10. Avoid third-party packages unless there is a clear need and the user is informed.
11. Use current, documented Apple APIs. Check deployment-target availability and concurrency requirements.
12. Do not invent API signatures. If uncertain, inspect the SDK/docs available in the environment or implement a conservative alternative.
13. Provide concise progress notes, build/test results, and the next action.
14. Keep the project README updated with build steps and limitations.

## Product rules
- The primary advantage is simplicity: one gallery for photos, videos, and music.
- The app must be friendly to nontechnical users.
- Keep original files in their existing locations.
- Scan only folders the user selects.
- No cloud upload, login, analytics, or network service in MVP.
- Never delete, move, or rename original media.
- Do not require Full Disk Access for normal use.
- Be transparent about supported media formats.
- Do not make indexing or thumbnail generation block the main UI.
- Provide useful empty/loading/error states.
- Do not build AI/semantic search, editing, or cloud features before the MVP is stable.

## Start here
Begin with **Milestone 0 and Milestone 1** from `IMPLEMENTATION_ROADMAP.md`.

Before writing code:
- Summarize the chosen deployment target and why.
- Explain the sandbox and security-scoped bookmark approach.
- Propose the initial source tree.
- Identify any macOS-version-dependent APIs.
- Then create the project and implement the UI shell.

If you have access to Xcode, build and launch the app. If not, do not pretend to have done so. Produce the files and exact build instructions for the user.

## Required deliverables
- Complete Xcode project/source tree.
- App builds and launches.
- README with setup/build instructions.
- Unit tests for core indexing/search logic where feasible.
- Manual test instructions.
- Known limitations and tested media formats.
- A clear list of files created or changed at each milestone.

## User communication style
Explain technical decisions in plain, practical language. Avoid overwhelming the user with jargon. Ask a question only if a decision genuinely blocks progress; otherwise choose a sensible default and document it.
