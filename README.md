<p align="left">
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

Release outputs:
- `build/FolderBar-<version>.zip`
- `build/FolderBar-<version>.dmg`

## Updates (Sparkle)

FolderBar uses Sparkle for auto-updates via an appcast hosted in this repo:

- Appcast URL: `https://raw.githubusercontent.com/jameskraus/FolderBar/main/appcast.xml`
- The release ZIP (`FolderBar-<version>.zip`) is the Sparkle update payload.
- The DMG (`FolderBar-<version>.dmg`) is the human-friendly installer.

### Keys

Sparkle updates are signed with an Ed25519 keypair:

- `SUPublicEDKey` (public key) is embedded in the app’s `Info.plist` at packaging time.
- The private key must never be committed (store it locally or as a CI secret).

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
SPARKLE_FEED_URL="https://raw.githubusercontent.com/jameskraus/FolderBar/main/appcast.xml"
```

Store the private key securely and set its path in `.env.local` (name used by release automation):

```bash
SPARKLE_ED_PRIVATE_KEY_FILE="/absolute/path/to/ed25519_private_key"
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
