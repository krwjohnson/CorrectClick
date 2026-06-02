# Architecture

## Version
1.0.0

## Overview

CorrectClick is a two-target macOS application:

```
CorrectClick.app                        (parent app — menu bar only)
└── Contents/PlugIns/
    └── CorrectClickExtension.appex     (Finder Sync Extension)
```

The parent app and the extension are separate processes. They do not communicate with each other in v1.0.0 — the extension handles everything independently.

---

## Parent app: CorrectClick

**Type:** Regular macOS application  
**Presence:** Menu bar only (`LSUIElement = YES` in Info.plist, so no Dock icon or app window)  
**Responsibility:** Staying alive in the menu bar so the extension bundle remains installed and accessible to Finder. Also handles first-launch onboarding (opening System Settings → Extensions).

The parent app does nothing at runtime beyond providing a "Enable Extension…" menu item and a Quit option. It exists because Finder Sync Extensions must be bundled inside a containing app — they cannot be distributed standalone.

**Key files:**
- `AppDelegate.swift` — launches the app, detects first run, opens System Settings
- `StatusBarController.swift` — creates and manages the NSStatusItem

---

## Extension: CorrectClickExtension

**Type:** Finder Sync Extension (`com.apple.FinderSync` extension point)  
**Host process:** Finder (the extension runs as an XPC service child of Finder)  
**Responsibility:** All user-facing functionality — registering monitored directories, providing the context menu, creating files, triggering rename mode.

The extension is a separate sandboxed process. macOS launches it automatically when Finder needs it and may suspend or terminate it at any time.

**Key files:**
- `FinderSync.swift` — `FIFinderSync` subclass; entry point for the extension
- `FileCreator.swift` — all file creation and rename logic

---

## Why this architecture?

Apple's supported mechanism for adding items to the Finder right-click menu since macOS 10.10 is the **Finder Sync Extension**. It was designed for cloud-sync providers (Dropbox, OneDrive, etc.) that need to badge files and show sync status, but the context menu API is available to any extension regardless of whether it syncs anything.

Alternative approaches (injecting code into Finder, using accessibility APIs, or scripting Finder via AppleScript) are either blocked by macOS security, unreliable across OS updates, or require intrusive permissions. The Finder Sync Extension is the only officially supported, App Store-compatible approach.

---

## Data flow for a "New Text File" action

```
User right-clicks in Finder
        │
        ▼
Finder asks extension for menu
        │
        ▼
FinderSync.menu(for:) returns NSMenu with "CorrectClick" submenu
        │
User clicks "New Text File"
        │
        ▼
FinderSync.newTextFile() fires
        │
FIFinderSyncController.default().targetedURL()
returns the directory the user right-clicked in
        │
        ▼
FileCreator.createTextFile(in:)
  1. Generates a unique filename (Untitled.txt, Untitled 2.txt, …)
  2. Writes empty Data to that URL
  3. Calls triggerRename(for:)
        │
        ▼
NSWorkspace.shared.activateFileViewerSelecting([url])
  — brings Finder to front and selects the new file
        │
DispatchQueue.main.asyncAfter(0.35s)
  — posts a Return key CGEvent to trigger inline rename
```
