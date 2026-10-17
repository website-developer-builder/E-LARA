# MediaHub for macOS

**Your photos, videos, and music. One simple library.**

MediaHub is a free, native Mac app that brings the photos, videos, and music scattered across your folders into one friendly gallery, so you can find and play your media without digging through Finder.

- 🖼️ **One gallery** for photos, videos, and music, with thumbnails
- 🔎 **Instant search** by filename across everything
- ▶️ **Built-in viewer and players**: photo viewer with zoom, video player, music mini-player that keeps playing while you browse
- ❤️ **Favorites**, Recently Added, and Recently Played
- 🔒 **Private by design**: no account, no cloud, no tracking. MediaHub only *reads* the folders you choose and never moves, renames, or deletes your files.

Requires **macOS 14 Sonoma or later**. Runs natively on Apple Silicon and Intel Macs.

---

## Download & install

1. Download **`MediaHub-0.1.0.zip`** from the [latest release](../../releases/latest).
2. Double-click the zip to unzip it, then drag **MediaHub.app** into your **Applications** folder.
3. Open it. The first time, macOS will warn you, because this free app isn't signed with a paid Apple Developer ID:
   - **macOS 15 Sequoia and later:** click **Done** on the warning, then open **System Settings ▸ Privacy & Security**, scroll down, and click **Open Anyway** next to "MediaHub". Confirm, and enter your password if asked.
   - **macOS 14 Sonoma:** right-click (or Control-click) **MediaHub.app** ▸ **Open** ▸ **Open**.

   You only need to do this once.
4. Click **Choose Folders…** and pick the folders where your photos, videos, and music live (for example Pictures, Movies, Music, or Downloads).

> Prefer not to run a downloaded app? Build it yourself from source in a couple of minutes (below). The result is identical.

## Using MediaHub

| | |
|---|---|
| **Add folders** | Choose Folders… on first launch, ⌘O, or drag folders onto the window |
| **Browse** | Sidebar: Home · All Media · Photos · Videos · Music · Favorites |
| **Search** | ⌘F, then type part of a filename |
| **Open / play** | Double-click, or select and press Return |
| **Details** | ⌘I shows size, dates, dimensions, duration, and location, plus **Show in Finder** |
| **Update** | ⌘R rescans your folders for new or changed files |
| **Remove a folder** | Settings ▸ Remove…. Only removes it from MediaHub; your files stay put |

**Supported formats** (anything macOS can open natively): JPG, PNG, HEIC, TIFF, GIF, BMP, WEBP, and common RAW photos · MOV, MP4, M4V videos · MP3, M4A/AAC, WAV, AIFF, CAF, AMR audio. Files macOS can't open show a friendly message instead of failing. See [MediaHub/README.md](MediaHub/README.md#formats-actually-verified) for exactly which formats were tested.

## Build from source

Needs Xcode 16 or later.

```bash
git clone https://github.com/website-developer-builder/MediaHub.git
cd MediaHub/MediaHub
open MediaHub.xcodeproj      # then press ⌘R in Xcode
```
Or from Terminal: `scripts/release.sh`, then `open dist/MediaHub.app`. Run the 39 tests with `scripts/test.sh`.

Technical details (architecture, sandbox and folder-permission design, tests, known limitations): **[MediaHub/README.md](MediaHub/README.md)**.

## Project documents

This repository also contains the product spec MediaHub was built from: [requirements](PRODUCT_REQUIREMENTS.md), [UX spec](UX_AND_UI_SPEC.md), [architecture](TECHNICAL_ARCHITECTURE.md), [roadmap](IMPLEMENTATION_ROADMAP.md), [test plan](TEST_PLAN.md), and [acceptance checklist](ACCEPTANCE_CHECKLIST.md).

## License

[MIT](LICENSE). Free to use, modify, and share.
