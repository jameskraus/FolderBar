# FolderBar

Menu bar app for surfacing folders and their contents.

## Product goals (short list)

- Native macOS menu bar app that shows immediate children of one or more folders.
- Items sorted by creation date (descending) with a fallback to modification date.
- Drag files out of the popover like Finder (highest priority).
- Popover-based UI (not a plain NSMenu) to keep drag reliable.

## Explicit non-goals

- No recursive browsing.
- No ignore patterns or hidden-file filtering configuration.
- No max-items configuration.
- No Mac App Store distribution.

## Build

```bash
swift build
```

## Run

```bash
swift run FolderBar
```

## Package (macOS app bundle)

```bash
./Scripts/package_app.sh
```

## Test

```bash
swift test
```

## Project structure

- `Sources/FolderBarCore` holds shared models and logic.
- `Sources/FolderBar` is the app entry point (menu bar UI).
- `Tests/FolderBarTests` contains unit tests for core behavior.

## Targets

- `FolderBarCore` (library) exposes core functionality.
- `FolderBar` (executable) composes the UI and uses `FolderBarCore`.
- `FolderBarTests` (test) validates `FolderBarCore`.
