<p align="center">
  <img src="Assets/Readme/FolderBar.png" alt="FolderBar icon" width="128">
</p>

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

## Dev loop (package + relaunch)

```bash
./Scripts/compile_and_run.sh
# or
make compile_and_run
```

## Lint / Format

```bash
brew install swiftformat swiftlint
make format
make lint
```

## Package (macOS app bundle)

```bash
./Scripts/package_app.sh
```

## Local code signing (optional)

`Scripts/package_app.sh` supports optional signing to reduce local permission prompts.

```bash
# Use a Developer ID or local signing identity
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./Scripts/package_app.sh

# Or force ad-hoc signing (default when SIGNING_IDENTITY is unset)
SIGN_ADHOC=1 ./Scripts/package_app.sh

# Skip signing entirely
SIGN_ADHOC=0 ./Scripts/package_app.sh
```

You can also set a local signing identity once in `.env.local` (ignored by git):

```bash
SIGNING_IDENTITY="Apple Development: Your Name (TEAMID)"
SIGN_ADHOC=1
```

Both `Scripts/package_app.sh` and `Scripts/compile_and_run.sh` will source `.env` and `.env.local` automatically (local overrides).

## Release (signed + notarized)

Create a `.env` file with release signing + notarization values:

```bash
RELEASE_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
NOTARY_KEY_ID="ABC123XYZ"
NOTARY_ISSUER_ID="00000000-0000-0000-0000-000000000000"
NOTARY_KEY_PATH="/path/to/AuthKey_ABC123XYZ.p8"
```

Then run:

```bash
./Scripts/release.sh
```

To list available identities:

```bash
security find-identity -v -p codesigning
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
