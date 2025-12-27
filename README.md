<p align="left">
  <img src="Assets/Readme/FolderBar.png" alt="FolderBar icon" width="128">
</p>

# FolderBar

Menu bar app for surfacing folders and their contents.

Regenerate the README icon:

```bash
make readme_icon
```

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

## Run (development)

FolderBar runs as a packaged `.app` (Sparkle and signing behave differently outside a real bundle).

### Default run (no setup)

This is the highest-utility development command (builds `build/FolderBar.app` and relaunches it):

```bash
./Scripts/compile_and_run.sh
```

By default, the packaging step will **ad-hoc sign** the app if no signing identity is configured. This avoids needing any certificates and keeps the command zero-config for new checkouts.

### Recommended dev signing (configure once)

For behavior closest to release builds (fewer permission prompts and consistent identity), set a signing identity once in `.env.local`:

```bash
SIGNING_IDENTITY="Apple Development: Your Name (TEAMID)"
```

To skip signing entirely, set:

```bash
SIGN_ADHOC=0
```

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

## Local code signing (optional, but recommended)

`Scripts/package_app.sh` supports signing to reduce local permission prompts and to behave more like production.

```bash
SIGNING_IDENTITY="Apple Development: Your Name (TEAMID)" ./Scripts/package_app.sh
```

You can set a default identity once in `.env.local` (ignored by git):

```bash
SIGNING_IDENTITY="Apple Development: Your Name (TEAMID)"
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

Build-only (no tag/GitHub/appcast changes):

```bash
SKIP_PUBLISH=1 ./Scripts/release.sh
```

## Updates (Sparkle)

FolderBar uses Sparkle for auto-updates via an appcast hosted in this repo:

- Appcast URL: `https://raw.githubusercontent.com/jameskraus/FolderBar/main/appcast.xml`
- The release ZIP (`FolderBar-<version>.zip`) is the Sparkle update payload.
- The DMG (`FolderBar-<version>.dmg`) is the human-friendly installer.

### Keys

Sparkle updates are signed with an Ed25519 keypair:

- `SUPublicEDKey` (public key) is embedded in the app’s `Info.plist` at packaging time.
- The private key must never be committed (stored in your Keychain by default).

One-time key generation (requires Sparkle tools):

```bash
brew install --cask sparkle
open /Applications/Sparkle.app
```

Then run:

```bash
/Applications/Sparkle.app/Contents/Resources/bin/generate_keys
```

Add the public key (base64) to `.env.local`:

```bash
SPARKLE_PUBLIC_ED_KEY="BASE64_PUBLIC_KEY_FROM_GENERATE_KEYS"
```

Optional (CI / non-interactive signing): export the private key to a file and set its path in `.env.local`:

```bash
SPARKLE_ED_PRIVATE_KEY_FILE="/absolute/path/to/ed25519_private_key"
```

### Troubleshooting

If Sparkle shows an update error and macOS says FolderBar was prevented from modifying apps, enable FolderBar in **System Settings → Privacy & Security → App Management**, then retry the update.

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
