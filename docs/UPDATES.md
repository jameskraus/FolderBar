# Updates (Sparkle)

FolderBar uses Sparkle for auto-updates via an appcast hosted in this repo.

## Appcast

- Appcast URL: `https://raw.githubusercontent.com/jameskraus/FolderBar/main/appcast.xml`
- The release ZIP (`FolderBar-<version>.zip`) is the Sparkle update payload.
- The DMG (`FolderBar-<version>.dmg`) is the human-friendly installer.

## Keys

Sparkle updates are signed with an Ed25519 keypair:

- `SUPublicEDKey` (public key) is embedded in the app’s `Info.plist` at packaging time.
- The private key must never be committed (stored in your Keychain by default).

### Key generation (one-time)

Requires Sparkle tools:

```bash
brew install --cask sparkle
open /Applications/Sparkle.app
```

Then run:

```bash
/Applications/Sparkle.app/Contents/Resources/bin/generate_keys
```

### Configure the public key

Add the public key (base64) to `.env.local`:

```bash
SPARKLE_PUBLIC_ED_KEY="BASE64_PUBLIC_KEY_FROM_GENERATE_KEYS"
```

### Optional: file-based private key (CI / non-interactive)

Export the private key to a file and set its path in `.env.local`:

```bash
SPARKLE_ED_PRIVATE_KEY_FILE="/absolute/path/to/ed25519_private_key"
```

## Troubleshooting

If Sparkle shows an update error and macOS says FolderBar was prevented from modifying apps, enable FolderBar in **System Settings → Privacy & Security → App Management**, then retry the update.

To list available identities:

```bash
security find-identity -v -p codesigning
```
