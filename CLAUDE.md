# CorrectClick — Developer Notes

## Project overview
macOS menu-bar app + Finder Sync Extension that adds a "CorrectClick" submenu to the Finder right-click menu for quick file creation. See the project spec at the top of any conversation for full feature details.

## Structure
- **CorrectClick/** — parent app (menu-bar only, `LSUIElement = YES`)
- **CorrectClickExtension/** — Finder Sync Extension (`FIFinderSync` subclass)
- **project.yml** — xcodegen spec; run `xcodegen generate` after editing it to regenerate the `.xcodeproj`

## Build
```
xcodegen generate   # only needed after editing project.yml
xcodebuild -scheme CorrectClick ...
```
Open `CorrectClick.xcodeproj` in Xcode. Both targets use Automatic signing — the developer team must be set in Xcode's Signing & Capabilities (or via `DEVELOPMENT_TEAM` in project.yml).

## SourceKit false positives
SourceKit reports errors for `FIFinderSync`, `FIFinderSyncController`, `FIMenuKind` etc. because it doesn't index the FinderSync framework outside of Xcode. These are not real errors — the project builds and the symbols resolve correctly.

## Current status
**Feature complete.** The extension is working:
- Right-clicking any folder in Finder shows a "CorrectClick" submenu
- File-creation actions: New Text File, New JSON File, New Python File, New CSV File, New Markdown File, New Shell Script (created executable), New YAML File, New HTML File (minimal boilerplate) — plus New Text File from Clipboard and New PNG from Clipboard
- Files are created with auto-incrementing names (Untitled, Untitled 2, etc.)
- After creation, Finder selects the file and enters rename mode

## Known limitations
- **No menu in iCloud Drive / OneDrive / Dropbox folders.** Finder Sync extensions are exclusive per directory — the first extension registered for a folder (iCloud's or the cloud provider's own `FIFinderSync`/File Provider integration) is the only one Finder will invoke there. There is no API-level workaround; `directoryURLs` cannot override another provider's claim on a directory. (Confirmed via Apple Developer Forums threads on this exact issue, Aug 2026.) Not planned to be fixed — documented here so it isn't rediscovered as a bug.

## To do (shipping checklist)
1. **Icons** — done. `AppIcon.appiconset` has all sizes; generated via `scripts/generate_icon.swift` / `scripts/build_icns.sh`.
2. **DMG installer** — done. `scripts/build_dmg.sh` archives, exports, and packages with `create-dmg` (custom background at `scripts/dmg_background.png`).
3. **First-run onboarding** — done, tested working, needs a commit. `CorrectClick/OnboardingView.swift` + `CorrectClick/OnboardingWindowController.swift` replace the bare System Settings launch with a welcome window; `AppDelegate.swift` and `StatusBarController.swift` now route through `OnboardingWindowController.shared`. While testing this, found and fixed a pre-existing bug: plain `@main` on the `NSApplicationDelegate` class never wires `NSApp.delegate` (that auto-wiring was specific to the deprecated `@NSApplicationMain`), so `applicationDidFinishLaunching` was never called — meaning the status-bar icon has never worked, only the Finder submenu (which lives in the separate extension process and has its own lifecycle). Fixed by adding `CorrectClick/main.swift` that explicitly does `NSApplication.shared.delegate = AppDelegate(); NSApplication.shared.run()`, and removing `@main` from `AppDelegate.swift`.
4. **Notarise** — not started. Requires:
   - Apple Developer account + Team ID set in `project.yml`'s `DEVELOPMENT_TEAM` (currently blank)
   - `scripts/ExportOptions.plist` switched from `method: development` to `developer-id`
   - `xcrun notarytool submit` + staple ticket to app bundle
5. **Sparkle auto-update** — not started; standard for direct-download Mac apps (add after first public release)

See `developer_documentation/` for deeper background: architecture, the Finder Sync extension, sandboxing/entitlements, file creation, build/debug, and distribution (one doc per topic, `01`–`06`).

## Key files
| File | Purpose |
|------|---------|
| `CorrectClickExtension/FinderSync.swift` | FIFinderSync subclass, "CorrectClick" menu definition, action handlers |
| `CorrectClickExtension/FileCreator.swift` | File creation logic, unique name generation, rename-mode trigger |
| `CorrectClickExtension/CorrectClickExtension.entitlements` | Sandbox + filesystem temporary exception |
| `CorrectClick/AppDelegate.swift` | First-launch: opens System Preferences → Extensions |
| `CorrectClick/StatusBarController.swift` | Menu-bar icon with "Enable Extension…" and Quit |

## Entitlements notes
- Parent app: sandboxed, no special entitlements needed
- Extension: sandboxed (`app-sandbox = true`) + `temporary-exception.files.absolute-path.read-write` with path `/` — this grants full filesystem read-write within the sandbox and is valid for notarised direct-download distribution. **App Store distribution would require a different architecture** (XPC relay: extension calls parent app via XPC, parent app holds user-selected file access and does the actual write).

## macOS 26 pluginkit quirk
On macOS 26, each new debug build is registered as a new plugin instance in a pending-approval state, even if the extension is already enabled in System Settings. A post-build script in `project.yml` runs `pluginkit -e use -i <bundle-id>` automatically after each build to approve it. Without this, the extension runs but Finder ignores it (the menu does not appear).
