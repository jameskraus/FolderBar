# FolderBar

Menu bar app for surfacing folders and their contents.

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
./package_app.sh
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
