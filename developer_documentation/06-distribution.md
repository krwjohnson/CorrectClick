# Distribution

## Version
1.0.0

## Overview

CorrectClick is distributed as a direct-download notarised app (`.dmg`). It is not currently submitted to the Mac App Store — the `temporary-exception.files.absolute-path.read-write` entitlement used by the extension is not permitted on the App Store (see [Sandboxing and Entitlements](03-sandboxing-and-entitlements.md)).

---

## Versioning

Version numbers follow [Semantic Versioning](https://semver.org): `MAJOR.MINOR.PATCH`

- **MAJOR** — breaking changes to supported macOS versions or behaviour
- **MINOR** — new features (new file types, new actions)
- **PATCH** — bug fixes, performance improvements, crash fixes

Set the version in `project.yml` under each target's `settings.base`:

```yaml
MARKETING_VERSION: "1.0.0"
CURRENT_PROJECT_VERSION: "1"
```

`MARKETING_VERSION` is the human-readable version (`1.0.0`). `CURRENT_PROJECT_VERSION` is the build number, incremented for every submitted build.

---

## Building a release

```bash
xcodebuild \
  -project CorrectClick.xcodeproj \
  -scheme CorrectClick \
  -configuration Release \
  -archivePath build/CorrectClick.xcarchive \
  archive
```

Then export the archive:

```bash
xcodebuild \
  -exportArchive \
  -archivePath build/CorrectClick.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist
```

A minimal `ExportOptions.plist` for direct-download (Developer ID) distribution:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

---

## Notarisation

Notarisation is required for the app to pass Gatekeeper on other Macs. Apple scans the app for malware and issues a ticket that is stapled to the bundle.

**Prerequisites:**
- Apple Developer Program membership
- App-specific password for your Apple ID (generate at appleid.apple.com)

**Submit for notarisation:**

```bash
xcrun notarytool submit build/export/CorrectClick.app \
  --apple-id "your@email.com" \
  --team-id "YOURTEAMID" \
  --password "app-specific-password" \
  --wait
```

`--wait` blocks until Apple returns a result (typically 1–5 minutes).

**Staple the ticket:**

```bash
xcrun stapler staple build/export/CorrectClick.app
```

Stapling embeds the notarisation ticket in the app bundle so Gatekeeper can verify it offline.

**Verify:**

```bash
spctl --assess --type execute --verbose build/export/CorrectClick.app
# Expected: source=Notarized Developer ID
```

---

## Creating a DMG

Install `create-dmg`:

```bash
brew install create-dmg
```

Build the DMG:

```bash
create-dmg \
  --volname "CorrectClick" \
  --volicon "CorrectClick/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 128 \
  --icon "CorrectClick.app" 175 190 \
  --hide-extension "CorrectClick.app" \
  --app-drop-link 425 190 \
  "build/CorrectClick-1.0.0.dmg" \
  "build/export/"
```

The DMG should also be notarised:

```bash
xcrun notarytool submit build/CorrectClick-1.0.0.dmg \
  --apple-id "your@email.com" \
  --team-id "YOURTEAMID" \
  --password "app-specific-password" \
  --wait

xcrun stapler staple build/CorrectClick-1.0.0.dmg
```

---

## App Store distribution (future)

Shipping on the App Store requires replacing the `temporary-exception` entitlement with an XPC architecture:

1. Add an XPC service target to the parent app
2. The extension sends file-creation requests to the XPC service via `NSXPCConnection`
3. The XPC service (running in the parent app's process group) holds `com.apple.security.files.user-selected.read-write` and a security-scoped bookmark for the target directory obtained from the extension
4. The XPC service writes the file and returns the final URL to the extension

This is a significant architectural change but makes the app fully App Store compliant.

---

## Release checklist

- [ ] Bump `MARKETING_VERSION` in `project.yml` and run `xcodegen generate`
- [ ] Update version in user-facing strings if any
- [ ] Archive with Release configuration
- [ ] Export with Developer ID method
- [ ] Notarise the `.app`
- [ ] Staple the ticket
- [ ] Verify with `spctl`
- [ ] Build the DMG
- [ ] Notarise the DMG
- [ ] Staple the DMG
- [ ] Test the DMG on a clean Mac (or a separate user account without Xcode)
- [ ] Tag the release in git: `git tag v1.0.0`
