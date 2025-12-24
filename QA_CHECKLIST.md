# FolderBar — Manual QA Checklist

Run this checklist before cutting a release, and after any significant UI/behavior change.

## Setup

- Install the app to `/Applications` (drag from DMG).
- Launch FolderBar from `/Applications` (Sparkle updates and code signing behave differently outside a packaged app).
- Keep Console open (optional) to inspect errors/crashes.

## Core behaviors

### Panel open/close

- Click the menu bar icon:
  - Panel opens anchored to the icon.
  - Clicking the icon again closes the panel.
- Click outside the panel:
  - Panel closes.
- Press Escape while panel is focused:
  - Panel closes.

### Folder selection + refresh

- With no folder selected:
  - Empty state shows “Choose Folder”.
  - Choosing a folder populates the panel list.
- With a folder selected:
  - Header shows folder name and path.
  - Items display with thumbnail/icon + metadata.
- Create a new file in the selected folder:
  - Panel updates (or updates after reopening) and shows the new file near the top.

### Sorting

- Verify items are sorted by creation date (newest first).
  - If creation date is unavailable, verify fallback behavior is stable (modification date).

## Drag-and-drop matrix (highest priority)

For a representative set of items (`.png`, `.jpg`, `.mp4`, and a plain text file):

- Drag from FolderBar into Finder:
  - Drop copies/moves behave like Finder drag semantics.
- Drag from FolderBar into:
  - Safari/Chrome → GitHub PR description/comment box → file attaches/uploads
  - Slack/Discord message composer → file attaches/uploads
  - Messages → file attaches

Verify:
- Drag starts reliably (no panel dismissal mid-drag).
- The dropped item is the correct file and opens/attaches successfully.

## Multi-folder behavior (when implemented)

- Add a second folder:
  - A second status item appears.
- Remove a folder:
  - Its status item disappears and no longer updates.
- Relaunch:
  - All configured folders restore correctly.

## Permissions + failures

- Choose a folder, then remove its permissions (or revoke Full Disk Access / Files & Folders permission):
  - App should not crash.
  - UI should show an understandable empty/error state.
- Choose a folder on an unavailable volume (e.g. external disk), then disconnect the volume:
  - App should not crash; panel should handle the missing path gracefully.

## Updates (Sparkle)

### Preconditions

- App must be running from `/Applications`.
- `SUFeedURL` is set in the packaged app (release builds do this by default).
- `SUPublicEDKey` is set in the packaged app.

### End-to-end update test

1) Install an older version from DMG (`vX.Y.Z`).
2) Publish a newer version (`vX.Y.(Z+1)`) and update `appcast.xml` to include it.
3) Launch the older app:
   - After the silent probe runs, the panel footer shows **Update available**.
4) Click **Update available**:
   - Settings opens.
5) In Settings → Updates, click **Update…**:
   - Sparkle UI appears and installs the update.
6) App relaunches:
   - About/Settings shows the new version.

### Negative cases

- If feed URL is missing/empty (or running via `swift run`):
  - Updates section shows “Updates unavailable”.
  - No Sparkle UI appears automatically.

