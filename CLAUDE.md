# CorrectClick — Developer Notes

## Project overview
macOS menu-bar app + Finder Sync Extension that adds a "New File" submenu to the Finder right-click menu. See the project spec at the top of any conversation for full feature details.

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

## Current status (last session)
The extension is installed and enabled in System Preferences but **the right-click menu is not appearing yet**. We are actively debugging this.

### What has been tried / ruled out
- `@objc(FinderSyncExtension)` on the class caused a class-name mismatch with `NSExtensionPrincipalClass` → removed
- `com.apple.security.app-sandbox = false` in extension entitlements → macOS rejects plug-ins that aren't sandboxed ("plug-ins must be sandboxed")
- `com.apple.security.temporary-exception.files.absolute-path.read-write` with `/` → caused the extension XPC service to crash immediately on launch (likely needs a provisioning profile to be valid)
- `directoryURLs = [URL(fileURLWithPath: "/")]` → changed to explicit paths (home dir, /Users, /Volumes) to be safer

### Current entitlements state
Extension has:
```xml
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.files.user-selected.read-write</key><true/>
```
Parent app has basic sandbox only.

### Next debugging step
Verify the extension process appears in Activity Monitor after hitting Run (scheme = CorrectClickExtension, host = Finder). If it still crashes, check Console.app filtered to `CorrectClickExtension` for the specific crash reason.

### File access strategy (unresolved)
The extension needs to write files to the directory the user right-clicked. In a sandboxed extension `user-selected.read-write` may not cover arbitrary Finder-targeted paths. Likely solutions:
1. XPC relay — extension calls parent app via XPC; parent app has broader file access and does the write
2. Provisioning profile with `temporary-exception.files.absolute-path.read-write` (path `/`)
3. Investigate whether `FIFinderSyncController.targetedURL()` returns a security-scoped URL the sandbox honours automatically

## Key files
| File | Purpose |
|------|---------|
| `CorrectClickExtension/FinderSync.swift` | FIFinderSync subclass, menu definition, action handlers |
| `CorrectClickExtension/FileCreator.swift` | File creation logic, unique name generation, rename-mode trigger |
| `CorrectClickExtension/CorrectClickExtension.entitlements` | Sandbox entitlements — the main pain point |
| `CorrectClick/AppDelegate.swift` | First-launch: opens System Preferences → Extensions |
| `CorrectClick/StatusBarController.swift` | Menu-bar icon with "Enable Extension…" and Quit |
