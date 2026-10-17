# MediaHub for macOS: Claude Build Pack

## What this is
A complete product and engineering handoff for building **MediaHub**, a simple native macOS app that acts as one gallery for local photos, videos, and music.

**Core promise:** Open one app and find your media without hunting through Finder.

The app should feel friendly and obvious, not like a professional media-management suite. It should preserve files in their original locations and create an organized library view over them.

## How to use this pack with Claude
1. Give Claude the whole extracted folder, or upload this ZIP.
2. Ask Claude to read `CLAUDE_BUILD_INSTRUCTIONS.md` first and then read the other documents.
3. Ask it to implement one milestone at a time, starting with Milestone 0 and Milestone 1.
4. Have Claude build and test after each milestone. Do not ask it to generate the whole app in one giant response.
5. Keep the documents in the project repository so Claude can refer to them as the source of truth.

## Documents
- `PRODUCT_REQUIREMENTS.md`: goals, scope, user stories, and acceptance criteria.
- `UX_AND_UI_SPEC.md`: navigation, screens, interaction rules, and visual direction.
- `TECHNICAL_ARCHITECTURE.md`: recommended native macOS structure and frameworks.
- `MEDIA_INDEXING_AND_PERMISSIONS.md`: safe scanning, macOS folder access, refresh, and file handling.
- `DATA_MODEL.md`: local data entities and persistence.
- `PLAYBACK_AND_PREVIEW.md`: photos, music, and video playback expectations.
- `SEARCH_AND_ORGANIZATION.md`: search, filtering, sorting, favorites, and collections.
- `IMPLEMENTATION_ROADMAP.md`: phased development plan.
- `TEST_PLAN.md`: functional, privacy, performance, and accessibility tests.
- `ACCEPTANCE_CHECKLIST.md`: definition of done for the first release.
- `CLAUDE_BUILD_INSTRUCTIONS.md`: instructions for Claude to work like a careful coding partner.
- `DECISIONS_AND_OPEN_QUESTIONS.md`: decisions already made and sensible defaults where details are not yet decided.

## Product name
MediaHub is a working name only. Keep the app name easy to change from one central configuration point.

## Important
This pack is a product specification, not a prebuilt compiled Mac app. Claude should create the Xcode project and source code, build it, run tests, and explain any setup steps that require the user.
