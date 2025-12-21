# FolderBar (working name) — Agent Build Plan (Swift 6.2+, macOS 15+)

> Goal: Build a modern **native** macOS **menu bar** app that watches one-or-more folders (**immediate children only**) and shows their contents sorted by **creation date (descending)** in a Gifox-like panel.
> Highest priority: **Drag files out of the panel** so it behaves like dragging from Finder (e.g., drag an image/mp4 into a GitHub PR description field to upload/attach).

---

## 0) Product definition

### Absolute MVP workflow (must be delivered early)

* User has a folder containing **images / videos** (e.g. `.png`, `.jpg`, `.gif`, `.mp4`).
* User opens the menu bar panel.
* User can **drag any item from the panel into other apps**:

  * Browsers (Safari/Chrome) → GitHub PR description/comment → file attaches/uploads
  * Slack / Messages → file attaches
  * Finder → copy/move behavior matches normal drag semantics
* Sorting is **newest first by creation date**.
* Clicking an item can open it (nice, but drag-and-drop is the priority).

### MVP+ (still “early”)

* Folder updates automatically with low overhead (no polling).
* User can add a second folder → second menu bar icon appears.
* Per-folder icon via **SF Symbols**.

### Out of scope (explicit)

* No “max items” configuration.
* No ignore patterns, no hidden-file filtering configuration.
* No recursive browsing; only immediate children.
* No Mac App Store distribution (direct download / GitHub Releases / Brew Cask is fine).

---

## 1) Technical strategy (match RepoBar/CodexBar style)

### RepoBar/CodexBar-inspired scaffolding

* **SwiftPM-first** repository (no committed `.xcodeproj` as the source of truth).
* Build/test from CLI: `swift build`, `swift test`.
* Package a real `.app` via repo scripts: `Scripts/package_app.sh` (CodexBar pattern).
* App is a SwiftPM **executable target** placed into `FolderBar.app/Contents/MacOS/FolderBar`.
* Use AppKit **`NSStatusItem`** for menu bar icons.
* Use a **popover/panel** for the dropdown UI (not a plain menu list), because **drag-and-drop out of a menu is fragile**.

### Key UI decision: use an `NSPopover` (or panel) for drag support

Dragging “out” of an `NSMenu` is often unreliable because menus are transient tracking UI; once the pointer leaves, the menu can dismiss and cancel interactions.

Implementation note: the current shell uses a custom `NSPanel` anchored to the
`NSStatusItem` button instead of `NSPopover` to avoid AppKit clamping/jumping on
tall menu bars. This keeps drag-out stable while still behaving like a popover.

To make drag-and-drop rock-solid, build the dropdown as:

* `NSStatusItem.button` click → toggle an `NSPopover`
* Popover content is a SwiftUI view (`NSHostingController`) with a List/Grid
* Use SwiftUI drag APIs (`onDrag`) backed by file URLs (`NSItemProvider`)

This is the main architectural change vs “menu only” implementations: it’s the cleanest way to ensure “Finder-like drag”.

---

## 2) Repository layout (target state)

```
FolderBar/
  Package.swift
  README.md
  AGENTS.md
  CHANGELOG.md
  LICENSE
  version.env

  Sources/
    FolderBarCore/
      Models/
        FolderConfig.swift
        FolderChildItem.swift
        FolderSnapshot.swift
      Storage/
        AppConfigStore.swift
      Scanning/
        FolderScanner.swift
      Watching/
        DirectoryWatcher.swift
      Util/
        DateFormatting.swift
        Logging.swift

    FolderBar/
      App/
        FolderBarApp.swift        // @main entry
        AppLifecycle.swift        // wiring + boot
      MenuBar/
        FolderManager.swift       // creates instances per folder
        FolderInstance.swift      // one folder -> one status item + watcher + snapshot
        StatusItemController.swift
        PopoverController.swift
      UI/
        FolderPanelView.swift     // SwiftUI popover content
        FolderRowView.swift
        IconPickerView.swift      // SF Symbols selection (later)
      Preferences/
        PreferencesWindow.swift   // optional; may not be needed early

  Tests/
    FolderBarTests/
      FolderScannerTests.swift
      ConfigStoreTests.swift
      (optional) DirectoryWatcherIntegrationTests.swift

  Scripts/
    compile_and_run.sh
    package_app.sh
    sign-and-notarize.sh          (later)
    release.sh                    (later)

  .github/workflows/ci.yml
  .swiftformat
  .swiftlint.yml
```

---

## 3) Build/run requirements (agents must keep these working)

### Required commands

* `swift build`
* `swift test`
* `./Scripts/package_app.sh debug`
* `open FolderBar.app`
* `./Scripts/compile_and_run.sh` (dev loop)

### Packaging requirements

`Scripts/package_app.sh` must:

* build arm64 (and optionally universal later)
* create `.app` bundle structure
* write `Info.plist` with:

  * `LSUIElement = true` (menu bar app, no Dock icon)
  * bundle id, version, min system version (macOS 15+)
* copy the SwiftPM-built executable into `Contents/MacOS/`
* copy resources (icons) if present

---

## 4) Core architecture and data flow

### Objects (high-level)

* `FolderConfig`

  * `id: UUID`
  * `folderURL: URL`
  * `displayName: String` (optional; default derived from folder name)
  * `symbolName: String` (SF Symbol name for that folder’s status icon; optional default)
* `FolderChildItem`

  * `url: URL`
  * `name: String`
  * `isDirectory: Bool`
  * `creationDate: Date?` (fallback to modification date for stability)
* `FolderSnapshot`

  * `folderURL`
  * `items: [FolderChildItem]` sorted by creationDate desc
  * `generatedAt: Date`
* `AppConfigStore`

  * load/save `AppConfig` JSON in Application Support
* `FolderScanner`

  * `scan(folderURL:) -> [FolderChildItem]` (immediate children only)
* `DirectoryWatcher`

  * file descriptor + `DispatchSourceFileSystemObject` (debounced)
* `FolderInstance`

  * owns one status item + popover + watcher + cached snapshot
* `FolderManager`

  * owns all folder instances, applies config changes (add/remove/change)

### Data flow

* On launch:

  * `AppConfigStore.load()` → `FolderManager.createInstances()`
* For each folder instance:

  * `FolderScanner.scan()` to create initial snapshot
  * `DirectoryWatcher` triggers → debounce → rescan → update snapshot → update UI
* UI state:

  * Snapshot updates delivered on `@MainActor` to SwiftUI view model (or directly via closures)

---

## 5) Concurrency and quality expectations

### Concurrency

* UI-facing properties on `@MainActor`.
* Directory watching runs on its own serial queue.
* Scanning runs off-main; publish results on main.

### Quality bar

* Swift 6 strict concurrency enabled.
* `swiftformat` and `swiftlint --strict` are mandatory CI gates.
* Use `os.Logger` categories for structured logs.
* Prefer small files and explicit types for novice friendliness.

---

## 6) Phased execution plan (prioritize drag-and-drop)

> Each phase ends with:

* ✅ `swift test` passing
* ✅ `./Scripts/compile_and_run.sh` passing
* ✅ Manual QA checklist items for the phase completed

---

### Phase 0 — Bootstrap repo and packaging (foundation)

**Deliverable:** app packages and runs as a menu bar accessory; shows a popover with placeholder UI.

Tasks:

* Create SwiftPM package with targets:

  * `FolderBarCore` (library)
  * `FolderBar` (executable)
  * `FolderBarTests`
* Add scripts:

  * `Scripts/package_app.sh`
  * `Scripts/compile_and_run.sh`
* Add CI (`.github/workflows/ci.yml`) to run build/test/lint
* Implement minimal menu bar shell:

  * One `NSStatusItem` with a system SF Symbol icon
  * Clicking toggles an `NSPopover`
  * Popover content is a SwiftUI view with dummy list

Acceptance criteria:

* Menu bar icon appears.
* Clicking opens a popover.
* App has no Dock icon.

---

### Phase 1 — Folder scanning + creation-date sorting + display in panel

**Deliverable:** panel shows real folder items sorted by creation date desc.

Tasks:

* Implement `FolderScanner.scan(folderURL:)`:

  * immediate children only (`contentsOfDirectory`)
  * resource keys: name, isDirectory, creationDate, contentModificationDate
  * sorting: `creationDate ?? contentModificationDate ?? .distantPast` descending
* In the app target:

  * choose an initial folder behavior:

    * If no config exists: prompt user to pick a folder on first run
    * Otherwise: default to `~/Downloads` until user changes (agent decision; prefer prompting)
  * display list of items in the popover with file icons

Unit tests:

* Temporary directory, create files in sequence, verify sorting.

Acceptance criteria:

* List updates when panel opens (manual refresh OK for this phase).
* Sorting is correct by creation date.

---

### Phase 2 — Highest priority: Drag-and-drop out of the panel (Finder-like)

**Deliverable:** dragging an item out of the popover works like Finder drag.

Tasks (core):

* Implement SwiftUI row drag:

  * `FolderRowView` uses `.onDrag { NSItemProvider(object: url as NSURL) }`
  * Ensure exported type supports file drops (UTType.fileURL)
* Compatibility improvements:

  * Add additional representations when needed:

    * file URL (primary)
    * optionally plain-text path as secondary for apps that prefer text drops
* UI behavior:

  * Ensure the popover doesn’t immediately dismiss when drag starts.

    * Prefer `NSPopover.Behavior.applicationDefined` (or `.semitransient`) and manage dismissal explicitly.
  * After a successful drop, it’s acceptable for popover to close (but not required). The key is: drag must not cancel.

Manual QA matrix (must pass):

* Drag image/video into:

  * Safari GitHub PR description → file attaches/uploads
  * Chrome GitHub PR description → file attaches/uploads
  * Slack message composer → file attaches
  * Finder window → behaves like dragging a file
* Dragging a folder should also work (Finder-like).

Acceptance criteria:

* Drag is reliable and feels like Finder.
* No random cancellation/dismiss mid-drag.

---

### Phase 3 — Low-overhead folder watching (automatic refresh)

**Deliverable:** panel updates automatically when folder contents change.

Tasks:

* Implement `DirectoryWatcher`:

  * `open(path, O_EVTONLY)`
  * dispatch source `.write`, `.rename`, `.delete`
  * debounce (200ms default)
* Wire watcher → rescan → update snapshot UI.
* Ensure no polling loop exists.

Edge cases:

* If folder becomes inaccessible (permissions / deleted), show an error state and provide “Change Folder…” action.

Acceptance criteria:

* Creating/removing/renaming a file updates list within ~0.5s.
* CPU stays idle when no changes.

---

### Phase 4 — Persistence + multi-folder icons (one icon per folder)

**Deliverable:** multiple status items, persisted across relaunch.

Tasks:

* Implement `AppConfigStore`:

  * store JSON at `~/Library/Application Support/FolderBar/config.json`
  * atomic write
  * `AppConfig { folders: [FolderConfig] }`
* Implement `FolderManager` to create one `FolderInstance` per config.
* Add UI actions:

  * “Add Folder…” → creates another status item
  * “Remove This Folder” (on that icon’s menu/panel footer)
  * “Change Folder…” updates config and reinitializes watcher

Acceptance criteria:

* Add second folder → second icon appears.
* Relaunch → icons restore.

Notes:

* No need for a big “list folders” screen; management can be done via per-icon actions and (optional) Preferences later.

---

### Phase 5 — Polished panel UI for media workflows (images/mp4)

**Deliverable:** the panel is optimized for quick media sharing.

Tasks:

* Improve row layout:

  * consistent spacing, filename truncation, relative date
  * show file type hint (e.g., “MP4”, “PNG”) if useful
* Add optional thumbnails:

  * For images/videos, generate thumbnails asynchronously (Quick Look thumbnail generator is a good candidate)
  * Cache thumbnails in memory
* Ensure drag uses the actual file URL, not a thumbnail proxy.

Acceptance criteria:

* Smooth scrolling.
* Thumbnails do not block UI.
* Drag remains reliable even with thumbnails.

---

### Phase 6 — Per-folder SF Symbol icon selection (simple, practical)

**Deliverable:** user can set each folder’s menu bar icon to an SF Symbol.

Tasks:

* Add `symbolName` to `FolderConfig`.
* Implement a lightweight icon picker UI:

  * Could be a simple Preferences window, or a sheet from the popover
  * Allow:

    * a text field to type symbol name
    * a preview of the symbol
    * a short curated list of commonly used symbols (“folder”, “photo”, “video”, “tray”, etc.)
* Apply icon:

  * `NSImage(systemSymbolName:)`, `isTemplate = true`

Acceptance criteria:

* Changing icon updates immediately.
* Persists across restart.

---

### Phase 7 — Release pipeline (direct download)

**Deliverable:** reproducible signed/notarized zip for GitHub Releases.

Tasks:

* Extend `package_app.sh` to embed version from `version.env`.
* Add signing + notarization script:

  * codesign app
  * zip
  * notarize via `notarytool`
  * staple
* Produce `FolderBar-x.y.z.zip` suitable for releases.

Acceptance criteria:

* On a clean machine, downloaded app opens without scary warnings (post-notarization).

---

## 7) Testing strategy

### Unit tests (must)

* `FolderScanner` sorting (creation date) and metadata extraction.
* `AppConfigStore` load/save and atomic write semantics.
* Date formatting helpers.

### Integration tests (optional / best-effort)

* Directory watcher triggers on file create/rename/delete.
  (Keep these tests isolated; they can be flaky on CI. If flaky, gate behind a CI flag or run them less frequently.)

### Manual QA (must keep updated)

* Drag-and-drop matrix (Safari/Chrome/Slack/Finder).
* Multi-folder icon creation and persistence.
* Folder permission failure handling.

---

## 8) Agent operating guidelines

### Development loop

* Always validate using the packaged `.app` (not just the `.build` binary):

  * `./Scripts/compile_and_run.sh`
* Always kill previous instances before launching a new build.

### Avoid ambiguous scope creep

* Do not add “max items”, ignore patterns, or hidden file toggles.
* Do not add recursive browsing.
* Do not add complicated preferences screens unless required by assigned phase.

### Implementation principles

* Keep “Core” pure and testable:

  * scanning / config / watcher should be in `FolderBarCore`
  * App target owns AppKit/SwiftUI UI and wiring
* Keep UI responsive:

  * scanning and thumbnail generation off-main
  * publish snapshots on `@MainActor`

---

## 9) Ready-to-assign ticket list (in priority order)

1. **Bootstrap + packaging**

* SwiftPM targets, scripts, CI, popover shell.

2. **Scan + render**

* Folder scanning, sorted list display.

3. **Drag-and-drop out of panel (highest priority)**

* `onDrag` with file URLs, popover behavior tuning, manual QA matrix.

4. **Watcher**

* DispatchSource watcher with debounce, auto-refresh.

5. **Persistence + multi-folder**

* JSON config store, multiple status items, add/remove/change folder.

6. **Polish for media**

* thumbnails, row layout, performance.

7. **SF Symbol icons**

* per-folder icon selection and persistence.

8. **Release pipeline**

* signing/notarization and GitHub release artifact.

---

## Glossary (for novice-friendly alignment)

* **SwiftPM**: Swift Package Manager. Here it replaces an Xcode project as the primary build definition.
* **Executable target**: A SwiftPM target that builds a runnable binary (our app binary).
* **NSStatusItem**: The native menu bar icon object.
* **NSPopover**: A small panel anchored to UI (here: the status item button).
* **onDrag**: SwiftUI modifier that provides drag data via `NSItemProvider`, enabling Finder-like drag behavior.
* **Debounce**: Coalesces bursts of filesystem events into one refresh after a short delay.
* **@MainActor**: Ensures UI state changes happen on the main thread.
