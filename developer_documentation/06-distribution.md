# Distribution

## Version
Tracked in the `VERSION` file at the repo root, not in this doc — it's bumped automatically by CI on every push to `main` (see below).

## Overview

CorrectClick is distributed as a direct-download notarised app (`.dmg`). It is not currently submitted to the Mac App Store — the `temporary-exception.files.absolute-path.read-write` entitlement used by the extension is not permitted on the App Store (see [Sandboxing and Entitlements](03-sandboxing-and-entitlements.md)).

---

## Versioning

Every commit to `main` gets a new patch version, automatically — see `.github/workflows/release.yml`. The `VERSION` file at the repo root is the single source of truth (currently `MAJOR.MINOR.PATCH`, patch bumped every push to `main`); nothing needs to be edited by hand in the normal case.

Mechanically: `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` in `project.yml` are just the *local dev default* (`1.0.0` / `1`). Release builds (CI, or `scripts/build_dmg.sh` run locally) override both at archive time from the `VERSION` file via `xcodebuild ... MARKETING_VERSION=$VERSION CURRENT_PROJECT_VERSION=$VERSION`, so `project.yml` itself never needs a commit just to bump the version. `CorrectClick/Info.plist` and `CorrectClickExtension/Info.plist` read these via `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`.

If you ever need a MINOR or MAJOR bump, edit the `VERSION` file by hand in the same commit — CI only ever increments the last component, it won't reset MINOR/MAJOR for you.

---

## Building a release

`scripts/build_dmg.sh` wraps the whole archive → export → DMG pipeline (including the fallback described below), and is what both local manual releases and CI use:

```bash
./scripts/build_dmg.sh                 # uses the VERSION file
VERSION=1.2.3 ./scripts/build_dmg.sh    # or override explicitly
```

It runs, roughly:

```bash
xcodebuild -project CorrectClick.xcodeproj -scheme CorrectClick -configuration Release \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$VERSION" \
  -archivePath build/CorrectClick.xcarchive archive

xcodebuild -exportArchive -archivePath build/CorrectClick.xcarchive \
  -exportPath build/export -exportOptionsPlist scripts/ExportOptions.plist
```

**Until `DEVELOPMENT_TEAM` is set in `project.yml`, `-exportArchive` fails** (`No Team Found in Archive`) — `build_dmg.sh` detects this and falls back to the ad-hoc-signed app straight from the `.xcarchive` instead of aborting, so DMGs keep building (unsigned, not notarisable) before a Developer Team is configured. **This is no longer the active path** — `DEVELOPMENT_TEAM` is set to `T4Q97VH6ST` and `scripts/ExportOptions.plist`'s `method` is `developer-id`, so every build now produces a real Developer ID signed export and the fallback only exists as a safety net (e.g. if the certificate is ever missing from the signing machine/runner).

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

## CI (`.github/workflows/release.yml`)

On every push to `main` (that isn't itself a version-bump commit):
1. Imports the Developer ID signing certificates into a temporary keychain (from GitHub secrets — see "Notarisation" below)
2. Runs the test suite
3. Bumps the patch version in `VERSION`
4. Runs `scripts/build_dmg.sh` (macOS GitHub-hosted runner; installs `xcodegen`/`create-dmg` via Homebrew first) — this now notarizes and staples both the `.app` and the `.dmg` as part of the same script
5. Generates a signed appcast entry (see Epic 3 / `RELEASING.md`)
6. Commits the `VERSION` bump + `appcast.xml` (`[skip ci]`) and tags `vX.Y.Z`, pushes both back to `main`
7. Publishes a GitHub Release for that tag with the notarized DMG attached
8. Deletes the temporary signing keychain

Every release build is now a real Developer ID signed, notarized DMG — verified end-to-end (see below), not just wired up untested.

---

## Notarisation

**Done and automated** — `scripts/build_dmg.sh` notarizes and staples automatically whenever it produces a real Developer ID export and finds credentials (`NOTARY_KEY_ID`, `NOTARY_ISSUER_ID`, plus `NOTARY_API_KEY` or a key at `~/.appstoreconnect/private_keys/`). See the script's own header comment and `RELEASING.md` for the full mechanics, credential setup, and CI secret names. What's below is the manual/by-hand version, useful for understanding what the script does or for a one-off outside the normal flow.

Notarisation is required for the app to pass Gatekeeper on other Macs. Apple scans the app for malware and issues a ticket that is stapled to the bundle.

**Prerequisites:**
- Apple Developer Program membership
- An App Store Connect API key (Team Key, Developer role) — Key ID, Issuer ID, and the downloaded `.p8` file. (Preferred over an app-specific password: it doesn't depend on your account's 2FA session, and is the right shape for a CI secret.)

**Submit for notarisation:**

```bash
xcrun notarytool submit build/export/CorrectClick.app \
  --key-id "KEYID" \
  --issuer "ISSUERID" \
  --key /path/to/AuthKey_KEYID.p8 \
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
spctl -a -vvv build/export/CorrectClick.app
# Expected: source=Notarized Developer ID
```

---

## Creating a DMG

Handled by `scripts/build_dmg.sh` (see above) — it wraps `create-dmg` with the project's icon/background, and also drops a copy of `scripts/uninstall.sh` (as `Uninstall CorrectClick.command`) both inside the app bundle and loose in the DMG. Install `create-dmg` once via `brew install create-dmg` (CI installs it fresh every run).

The DMG is also notarised and stapled automatically (same script, same credentials) — it notarizes the `.app` first (so the ticket exists before the app is packaged), builds the DMG containing that already-stapled app, then notarizes and staples the DMG itself as a second, separate submission:

```bash
xcrun notarytool submit build/CorrectClick-1.0.0.dmg \
  --key-id "KEYID" \
  --issuer "ISSUERID" \
  --key /path/to/AuthKey_KEYID.p8 \
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

Automatic on every push to `main` (via `.github/workflows/release.yml`):
- [x] Import Developer ID signing certificates into a CI keychain
- [x] Run the test suite
- [x] Bump patch version (`VERSION` file) and tag `vX.Y.Z`
- [x] Archive, export with a real Developer ID signature, build the DMG
- [x] Notarise the `.app`, staple it
- [x] Notarise the `.dmg`, staple it
- [x] Generate a signed appcast entry
- [x] Publish a GitHub Release with the notarized DMG attached

Still worth doing manually, at least once, before calling this fully proven:
- [ ] Test the DMG on a clean Mac (or a separate user account without Xcode) — everything above has been verified locally (`spctl` reports `Notarized Developer ID` on both the `.app` and the copy extracted from the `.dmg`) and via the actual `build_dmg.sh` script CI runs, but not yet via a real download-and-open on a machine that's never seen this app before.
- [ ] For a MINOR/MAJOR bump, edit `VERSION` by hand in the triggering commit — CI only increments PATCH
