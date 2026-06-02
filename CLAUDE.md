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
- All three actions are implemented: New Text File, New Text File from Clipboard, New PNG from Clipboard
- Files are created with auto-incrementing names (Untitled, Untitled 2, etc.)
- After creation, Finder selects the file and enters rename mode

## To do (shipping checklist)
1. **Icons** — app currently has no icon; needed before notarisation
   - App icon (1024×1024 source, all sizes in AppIcon.appiconset)
   - Menu bar template image (22pt, black/transparent, @1x and @2x)
2. **Notarise** — required for Gatekeeper on other Macs
   - Requires Apple Developer account
   - `xcrun notarytool submit` + staple ticket to app bundle
3. **DMG installer** — standard direct-download delivery format
   - `brew install create-dmg` then script the build
4. **First-run onboarding** — replace the bare System Settings launch with a small welcome window explaining how to enable the extension
5. **Sparkle auto-update** — standard for direct-download Mac apps (add after first public release)

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
