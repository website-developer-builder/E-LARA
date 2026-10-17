# E-LARA for macOS

![E-LARA: Your media, all together.](Branding/E-LARA-brand-sheet.png)

**Your media, all together.**

E-LARA is a free, native Mac app that brings the photos, videos, and music scattered across your folders into one friendly gallery, so you can find and play your media without digging through Finder.

- 🖼️ **One gallery** for photos, videos, and music, with thumbnails
- 🔎 **Instant search** by filename across everything
- ⎵ **Quick View**: select anything and press **Space** to preview it instantly (hold Space to peek), and use the **arrow keys** to flip through photos, videos, and songs
- ▶️ **Built-in viewer and players**: photo viewer with zoom, video player, music mini-player that keeps playing while you browse
- ❤️ **Favorites**, Recently Added, and Recently Played
- 🔒 **Private by design**: no account, no cloud, no tracking. E-LARA only *reads* the folders you choose and never moves, renames, or deletes your files.

Requires **macOS 14 Sonoma or later**. Runs natively on Apple Silicon and Intel Macs.

---

## Download & install

1. Download **`E-LARA-0.3.0.zip`** from the [latest release](../../releases/latest).
2. Double-click the zip to unzip it, then drag **E-LARA.app** into your **Applications** folder.
3. Open it. The first time, macOS will warn you, because this free app isn't signed with a paid Apple Developer ID:
   - **macOS 15 Sequoia and later:** click **Done** on the warning, then open **System Settings ▸ Privacy & Security**, scroll down, and click **Open Anyway** next to "E-LARA". Confirm, and enter your password if asked.
   - **macOS 14 Sonoma:** right-click (or Control-click) **E-LARA.app** ▸ **Open** ▸ **Open**.

   You only need to do this once.
4. Click **Choose Folders…** and pick the folders where your photos, videos, and music live (for example Pictures, Movies, Music, or Downloads).

> Prefer not to run a downloaded app? Build it yourself from source in a couple of minutes (below). The result is identical.

## Using E-LARA

| | |
|---|---|
| **Add folders** | Choose Folders… on first launch, ⌘O, or drag folders onto the window |
| **Browse** | Sidebar: Home · All Media · Photos · Videos · Music · Favorites |
| **Search** | ⌘F, then type part of a filename |
| **Quick View** | Select an item and tap **Space** to preview; **← → ↑ ↓** to move between items; Space or Esc to close. Hold Space to peek |
| **Open / play** | Double-click, or select and press Return |
| **Show in Finder** | Select an item and click the folder button in the toolbar (or press ⇧⌘R, or right-click ▸ Show in Finder) to see its original file in Finder. If it was moved or deleted, E-LARA opens the folder where it used to be |
| **Details** | ⌘I shows size, dates, dimensions, duration, and location |
| **Update** | ⌘R rescans your folders for new or changed files |
| **Remove a folder** | Settings ▸ Remove…. Only removes it from E-LARA; your files stay put |

**Supported formats** (anything macOS can open natively): JPG, PNG, HEIC, TIFF, GIF, BMP, WEBP, and common RAW photos · MOV, MP4, M4V videos · MP3, M4A/AAC, WAV, AIFF, CAF, AMR audio. Files macOS can't open show a friendly message instead of failing. See [ELARA/README.md](ELARA/README.md#formats-actually-verified) for exactly which formats were tested.

## Build from source

Needs Xcode 16 or later.

```bash
git clone https://github.com/website-developer-builder/E-LARA.git
cd E-LARA/ELARA
open ELARA.xcodeproj      # then press ⌘R in Xcode
```
Or from Terminal: `scripts/release.sh`, then `open dist/E-LARA.app`. Run the 60 tests with `scripts/test.sh`.

Technical details (architecture, sandbox and folder-permission design, tests, known limitations): **[ELARA/README.md](ELARA/README.md)**.

## Project documents

This repository also contains the product spec E-LARA was built from (under its working name "MediaHub"): [requirements](PRODUCT_REQUIREMENTS.md), [UX spec](UX_AND_UI_SPEC.md), [architecture](TECHNICAL_ARCHITECTURE.md), [roadmap](IMPLEMENTATION_ROADMAP.md), [test plan](TEST_PLAN.md), and [acceptance checklist](ACCEPTANCE_CHECKLIST.md).

> **Upgrading from MediaHub?** E-LARA is the same app, renamed. Install E-LARA and delete the old MediaHub.app. Your library, favorites, and folder permissions carry over automatically.

## License

[MIT](LICENSE). Free to use, modify, and share.
