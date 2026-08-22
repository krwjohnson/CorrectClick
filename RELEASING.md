# Releasing CorrectClick

Every push to `main` (that isn't itself a `[skip ci]` release commit) runs
`.github/workflows/release.yml`, which:

1. Imports the Developer ID signing certificates into a temporary CI
   keychain (from GitHub secrets — see "Notarization & signing" below).
2. Runs `CorrectClickTests` — a failing test aborts here, before anything
   below touches the repo or publishes anything.
3. Bumps the patch version in `VERSION`.
4. Builds, notarizes, and staples `CorrectClick-X.Y.Z.dmg`
   (`scripts/build_dmg.sh`).
5. Signs a new appcast entry for that DMG (`scripts/generate_appcast.sh`)
   and merges it into the repo's `appcast.xml`.
6. Commits `VERSION` + `appcast.xml` together, tags `vX.Y.Z`, and pushes
   both to `main`.
7. Creates a GitHub Release for that tag with the notarized DMG attached.
8. Deletes the temporary signing keychain.

Nothing here needs manual XML editing, manual notarization, or a manual
version bump — pushing to `main` is the entire release action.

## Notarization & signing

Fully wired and verified — real Developer ID signature, real notarization
submission, real staple, confirmed with `spctl` on both the raw `.app` and
on a copy extracted from a freshly-built `.dmg` (`spctl` reports
`Notarized Developer ID` in both cases). This was tested by hand against
the actual `scripts/build_dmg.sh` script before any of it was wired into CI.

**Two separate credential sets are involved, both needed:**

1. **Code signing certificates** (so the build itself is really Developer ID
   signed): `DEVELOPMENT_TEAM` in `project.yml` is set to the real Team ID
   (`T4Q97VH6ST`), and `scripts/ExportOptions.plist`'s `method` is
   `developer-id`. Two certificate types are required — the archive step
   signs with an **Apple Development** cert, then `-exportArchive` re-signs
   with a **Developer ID Application** cert. Locally, both just need to be
   present in your login Keychain (Xcode → Settings → Accounts → Manage
   Certificates…, or generated when you first archive with automatic
   signing). For CI, both are exported as password-protected `.p12` files,
   base64-encoded, and stored as GitHub secrets:
   - `DEVELOPER_CERTIFICATE_P12` / `DEVELOPER_CERTIFICATE_PASSWORD`
   - `DEVELOPER_ID_CERTIFICATE_P12` / `DEVELOPER_ID_CERTIFICATE_PASSWORD`

   The "Import signing certificates" workflow step decodes both into a
   throwaway keychain for the run, and deletes it again at the end
   (`if: always()`, so it's cleaned up even on failure).

2. **Notarization credentials** (an App Store Connect API key, Team Key,
   Developer role — preferred over an app-specific password since it
   doesn't depend on 2FA session state and is the right shape for a CI
   secret): `NOTARY_KEY_ID`, `NOTARY_ISSUER_ID`, and `NOTARY_API_KEY` (the
   `.p8` file's contents). Locally, `scripts/build_dmg.sh` will also happily
   pick up a key sitting at Apple's own conventional location —
   `~/.appstoreconnect/private_keys/AuthKey_<NOTARY_KEY_ID>.p8` — so you
   only need `NOTARY_KEY_ID`/`NOTARY_ISSUER_ID` set as env vars for a local
   run, no `NOTARY_API_KEY` needed.

**If any of the five signing/notarization secrets are missing**,
`scripts/build_dmg.sh` degrades gracefully rather than failing the build:
no Developer ID certs → ad-hoc-signed fallback (not notarizable, but the
DMG still builds); Developer ID certs present but no notary credentials →
signed but unnotarized DMG, with a message telling you how to notarize it
by hand. This mirrors how the whole pipeline behaved before any of this was
set up, so a secret expiring or being rotated out doesn't hard-break
releases — it just quietly drops back to a lesser-signed build until fixed.

**Rotating either credential set:** regenerate in Xcode/the developer
portal, re-export/re-encode, and replace the corresponding GitHub secrets.
Nothing else in the repo needs to change — `project.yml`'s `DEVELOPMENT_TEAM`
only changes if the actual Apple Developer Team changes, not on routine
cert rotation.

## Auto-update (Sparkle)

CorrectClick ships with [Sparkle](https://sparkle-project.org) wired up for
in-app update checks (Epic 3). A few things about how it's set up here,
specifically:

- **Feed URL:** `https://raw.githubusercontent.com/krwjohnson/CorrectClick/main/appcast.xml`
  (see `SUFeedURL` in `CorrectClick/Info.plist`). This only works because the
  repo is **public** — a private repo's raw file URLs, and its Release asset
  download links, both require an authenticated request, which Sparkle's
  updater on an end user's Mac can't provide. If this repo is ever made
  private again, auto-update (and the plain DMG download link) breaks until
  it's public again or the feed/DMG move to a host that doesn't require auth
  (e.g. GitHub Pages needs a paid plan for a private repo; S3/Cloudflare
  Pages are other options).
- **Signing key:** Sparkle requires every update to carry a valid EdDSA
  signature, checked against the public key embedded in the app
  (`SUPublicEDKey` in Info.plist). The matching **private** key must never be
  committed — it's a GitHub Actions secret named `SPARKLE_PRIVATE_KEY`
  (Settings → Secrets and variables → Actions). Anyone who gets that key can
  sign a malicious "update" that every installed copy of the app will trust.
  - The key currently in use was generated with Sparkle's `generate_keys`
    tool and is also stored in the local login Keychain of whichever machine
    ran it (item "Private key for signing Sparkle updates", account
    `correctclick`) — that's Sparkle's own recommended local-signing setup,
    separate from the CI secret.
  - **Rotating the key:** run `generate_keys --account correctclick` again
    to create a new pair, update `SUPublicEDKey` in `CorrectClick/Info.plist`
    to the new public key, and replace the `SPARKLE_PRIVATE_KEY` GitHub
    secret with the new private key. Old appcast entries stay signed with
    the old key and will simply stop being trusted by apps that have already
    updated past them — this is only safe to do between releases, not
    something to automate.
- **`scripts/generate_appcast.sh`** downloads/uses Sparkle's `generate_appcast`
  CLI (pinned to the same version as `project.yml`'s Sparkle SPM package —
  keep those two in sync when bumping Sparkle). It seeds a scratch directory
  with the repo's *existing* `appcast.xml` plus just the DMG that was built
  this run, so it only needs to sign the one new version — it merges into
  the existing feed rather than needing every past release's DMG on disk.

**Update installs now have what they need to actually pass Gatekeeper** —
notarization was the missing piece (see above); the update *check* itself
never depended on it. What's still genuinely unverified: an actual Sparkle
check-download-install cycle against a real published release, from a
second machine. Everything up to and including "does a downloaded,
notarized DMG pass Gatekeeper" has been confirmed by hand; the
Sparkle-specific install mechanics (the `Installer.xpc` swap-in step) has
not been separately exercised end-to-end yet.

### Sandboxing note

The app is sandboxed (`com.apple.security.app-sandbox`). Sparkle 2.x handles
this via two XPC services (`Installer.xpc`, `Downloader.xpc`) bundled
*inside* `Sparkle.framework` itself — they're launched from their nested
location inside `Contents/Frameworks/Sparkle.framework/…`, not copied out to
a top-level `Contents/XPCServices/` the way a normal XPC service target
would be. This was confirmed by diffing a real CorrectClick build against
Sparkle's own official sample app bundle — both have the exact same layout,
so no extra Xcode build phase is needed for this to work. What *is* needed,
and is already in `CorrectClick.entitlements`: a
`temporary-exception.mach-lookup.global-name` entry for
`$(PRODUCT_BUNDLE_IDENTIFIER)-spks` / `-spki` (Sparkle's fixed naming
convention for those two services), plus `SUEnableInstallerLauncherService`
and `SUEnableDownloaderService` in Info.plist. With the downloader service
enabled, the app itself needs no separate network entitlement.
