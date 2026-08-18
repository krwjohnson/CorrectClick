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

**Until `DEVELOPMENT_TEAM` is set in `project.yml`, `-exportArchive` fails** (`No Team Found in Archive`) — `build_dmg.sh` detects this and falls back to the ad-hoc-signed app straight from the `.xcarchive` instead of aborting, so DMGs keep building (unsigned, not notarisable) before a Developer Team is configured. Once `DEVELOPMENT_TEAM` and `scripts/ExportOptions.plist`'s `method` (→ `developer-id`) are set for real, this fallback stops triggering and every build becomes notarisable.

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
1. Bumps the patch version in `VERSION`
2. Runs `scripts/build_dmg.sh` (macOS GitHub-hosted runner; installs `xcodegen`/`create-dmg` via Homebrew first)
3. Commits the `VERSION` bump (`[skip ci]`) and tags `vX.Y.Z`, pushes both back to `main`
4. Publishes a GitHub Release for that tag with the DMG attached

This produces an **unsigned, ad-hoc build** for now (see the fallback above) — fine for internal testing/distribution among people who know to right-click ▸ Open past Gatekeeper, not yet suitable for general public distribution. Notarisation (below) is still a manual, separate step until `DEVELOPMENT_TEAM` is configured and wired into the workflow.

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

Handled by `scripts/build_dmg.sh` (see above) — it wraps `create-dmg` with the project's icon/background, and also drops a copy of `scripts/uninstall.sh` (as `Uninstall CorrectClick.command`) both inside the app bundle and loose in the DMG. Install `create-dmg` once via `brew install create-dmg` (CI installs it fresh every run).

Once notarisation is set up, the DMG produced by `build_dmg.sh` should also be notarised:

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

Automatic on every push to `main` (via `.github/workflows/release.yml`):
- [x] Bump patch version (`VERSION` file) and tag `vX.Y.Z`
- [x] Archive, export (or ad-hoc fallback), build the DMG
- [x] Publish a GitHub Release with the DMG attached

Still manual, until notarisation is set up:
- [ ] Set `DEVELOPMENT_TEAM` in `project.yml` and switch `scripts/ExportOptions.plist`'s `method` to `developer-id`
- [ ] Notarise the `.app` and staple the ticket
- [ ] Verify with `spctl`
- [ ] Notarise the DMG and staple it
- [ ] Test the DMG on a clean Mac (or a separate user account without Xcode)
- [ ] For a MINOR/MAJOR bump, edit `VERSION` by hand in the triggering commit — CI only increments PATCH
