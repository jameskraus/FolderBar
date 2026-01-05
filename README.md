<p align="left">
  <img src="Assets/Readme/FolderBar.png" alt="FolderBar icon" width="128">
</p>

# FolderBar

Quickly drag-and-drop files from an important folder right from your menu bar.

## Preview

https://github.com/user-attachments/assets/5ce4c1cf-1b59-431a-8e02-6a9e056ec85a

## Install

Download the latest release DMG from https://github.com/jameskraus/FolderBar/releases/latest, open it, and drag FolderBar.app into your Applications folder.

## Agent notes

Agent-oriented docs (product goals/non-goals, project structure, release workflow) live in `AGENTS.md`.

## Build

```bash
swift build
```

## Run (development)

FolderBar runs as a packaged `.app` (Sparkle and signing behave differently outside a real bundle).

```bash
./Scripts/compile_and_run.sh
```

### Dev signing

Set a signing identity once in `.env.local`:

```bash
SIGNING_IDENTITY="Apple Development: Your Name (TEAMID)"
```

If `SIGNING_IDENTITY` is not set, packaging will fall back to ad-hoc signing.

## Lint / Format

```bash
brew install swiftformat swiftlint
make format
make lint
```

## Git Hooks (recommended)

```bash
./Scripts/install_git_hooks.sh
```

This appends a call to the repo-managed hook into your local `.git/hooks/pre-push` (so existing hooks like `bd` keep working).

## Package (macOS app bundle)

```bash
./Scripts/package_app.sh
```
Both `Scripts/package_app.sh` and `Scripts/compile_and_run.sh` will source `.env` and `.env.local` automatically (local overrides).

## Release (signed + notarized + published)

If someone tells you to release the app, do this:

1) Ensure you’re on `main` with a clean working tree.
2) Bump `version.env` (the release script reads `VERSION=` from here).
3) Run `./Scripts/release.sh`.

Pre-req: create a `.env` file with release signing + notarization values, and set `SPARKLE_PUBLIC_ED_KEY` in `.env.local`:

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

This produces + publishes:
- `build/FolderBar-<version>.zip`
- `build/FolderBar-<version>.dmg`
- Git tag `v<version>`
- GitHub Release assets
- `appcast.xml` update committed to `main`

## Updates

Sparkle update/appcast/key details live in `docs/UPDATES.md`.

## Test

```bash
swift test
```
