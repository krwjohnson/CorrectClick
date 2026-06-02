# Building and Debugging

## Version
1.0.0

## Prerequisites

| Tool | Purpose | Install |
|---|---|---|
| Xcode 15+ | Build, sign, run | Mac App Store |
| xcodegen | Generate `.xcodeproj` from `project.yml` | `brew install xcodegen` |
| Apple Developer account | Signing and notarisation | developer.apple.com |

---

## Generating the Xcode project

The `.xcodeproj` is generated from `project.yml` and is **not committed to git**. After cloning or editing `project.yml`, run:

```bash
xcodegen generate
```

Then open `CorrectClick.xcodeproj` in Xcode and set your Development Team in **Signing & Capabilities** for both targets.

---

## Building from the command line

```bash
xcodebuild \
  -project CorrectClick.xcodeproj \
  -scheme CorrectClick \
  -configuration Release \
  build
```

---

## Running in Xcode

1. Select the **CorrectClickExtension** scheme in the Xcode toolbar
2. Press **Run** — Xcode will ask which app to use as the host
3. Select **Finder**

Xcode launches Finder with your debug extension injected. The parent app does not need to be running for the extension to work during development.

To test the parent app independently, switch the scheme to **CorrectClick** and run normally.

---

## The macOS 26 pluginkit approval quirk

On macOS 26, each new build binary gets a new UUID. macOS registers it as a new extension instance in a **pending-approval** (`!`) state, separate from the system-enabled extension. Finder ignores pending instances — the context menu will not appear.

A post-build script in `project.yml` handles this automatically by running:

```bash
pluginkit -e use -i "$BUNDLE_ID"
```

This runs after every successful build, so you should never need to do it manually. If the menu stops appearing after a build, check whether the script ran:

```bash
pluginkit -m -A -v | grep CorrectClick
# Should show + not !
```

---

## Reloading the extension after a code change

The safest sequence for picking up changes:

1. Stop the current run in Xcode
2. Build and Run again (the post-build script re-approves the new binary)
3. If the menu still doesn't appear, restart Finder: `killall Finder`

Finder caches extension state aggressively. A full Finder restart is the most reliable way to force it to load the new binary.

---

## Inspecting the extension with Console.app

Filter by process name `CorrectClickExtension` to see any runtime output or crashes. The extension writes no logs by default; you can add `os_log` calls during debugging:

```swift
import os
private let log = Logger(subsystem: "com.yourteam.CorrectClick", category: "extension")
log.debug("menu(for:) called")
```

---

## Inspecting the built bundle

The extension is embedded inside the parent app:

```
CorrectClick.app/
└── Contents/
    ├── MacOS/CorrectClick
    ├── Info.plist
    └── PlugIns/
        └── CorrectClickExtension.appex/
            └── Contents/
                ├── MacOS/CorrectClickExtension
                ├── MacOS/CorrectClickExtension.debug.dylib   ← actual Swift code in debug builds
                └── Info.plist
```

In Debug builds, Xcode uses a stub executor pattern: the main binary is a thin launcher and the Swift code lives in `CorrectClickExtension.debug.dylib`. Both are present in the built `.appex`. This is normal and does not affect functionality.

To verify the embedded entitlements on the built extension:

```bash
codesign -d --entitlements - path/to/CorrectClickExtension.appex
```

---

## Common problems

| Symptom | Likely cause | Fix |
|---|---|---|
| "plug-ins must be sandboxed" in Console | `app-sandbox = false` in extension entitlements | Set it to `true` |
| Extension shows `!` in pluginkit | New build not yet approved | Run `pluginkit -e use -i <bundle-id>` or check the post-build script ran |
| Menu appears but actions do nothing | Filesystem write blocked by sandbox | Verify `temporary-exception.files.absolute-path.read-write` is in the entitlements |
| Menu only appears in one directory | `directoryURLs` not set to `/` | Set `FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]` |
| Menu not appearing after rebuild | Old extension binary still loaded | Stop, rebuild, run — or `killall Finder` |
| Signing certificate mismatch build error | Extension and parent app signed by different certs | Set matching Team in Signing & Capabilities for both targets |
