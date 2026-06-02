# File Creation

## Version
1.0.0

## Overview

All file creation logic lives in `CorrectClickExtension/FileCreator.swift`. It is a caseless enum used as a namespace — all methods are `static`.

---

## Actions

### New Text File

```swift
static func createTextFile(in directory: URL)
```

Creates an empty `.txt` file. Writes `Data()` (zero bytes) atomically to the resolved URL.

### New Text File from Clipboard

```swift
static func createTextFileFromClipboard(in directory: URL)
```

Reads the clipboard in this order:

1. `NSPasteboard.string(forType: .string)` — plain text, preferred
2. `NSPasteboard.data(forType: .rtf)` → `NSAttributedString(rtf:)` → `.string` — strips RTF formatting to plain text
3. If neither is available, shows a notification and returns without creating a file

### New PNG from Clipboard

```swift
static func createPNGFromClipboard(in directory: URL)
```

1. `NSImage(pasteboard:)` — accepts any image on the clipboard (screenshots, copied images, etc.)
2. Converts to PNG via `NSBitmapImageRep` → `.representation(using: .png, properties: [:])`
3. If no image is present, shows a notification and returns

---

## Unique filename generation

```swift
static func uniqueURL(in directory: URL, stem: String, ext: String) -> URL
```

Checks for filename collisions by probing the filesystem directly with `FileManager.default.fileExists`. The naming sequence is:

```
Untitled.txt
Untitled 2.txt
Untitled 3.txt
...
```

This matches Finder's own naming convention for new folders. The check-then-write sequence has a theoretical race condition (another process could create the file between the check and the write) but this is acceptable for a UI tool where simultaneous file creation in the same directory by two processes is vanishingly unlikely.

---

## Writing the file

```swift
try data.write(to: url, options: .atomic)
```

The `.atomic` option writes to a temporary file first and then renames it into place, ensuring the target path either contains the complete file or nothing — no partial writes.

---

## Rename mode

After writing, `triggerRename(for:)` replicates Finder's "New Folder" behaviour — the file is selected and immediately ready to be renamed.

```swift
private static func triggerRename(for url: URL) {
    NSWorkspace.shared.activateFileViewerSelecting([url])

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
        postReturnKey()
    }
}
```

**Step 1 — Select and reveal:**  
`activateFileViewerSelecting` tells Finder to bring itself to the front and select the specified file. This is a standard `NSWorkspace` API that works from any process.

**Step 2 — Enter rename mode:**  
In Finder, pressing Return while a file is selected enters inline rename mode. We synthesise this keystroke using `CGEvent`:

```swift
private static func postReturnKey() {
    let src = CGEventSource(stateID: .hidSystemState)
    let keyCode: CGKeyCode = 0x24 // Return
    CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)?.post(tap: .cgSessionEventTap)
    CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)?.post(tap: .cgSessionEventTap)
}
```

The 0.35-second delay gives Finder time to process `activateFileViewerSelecting` and complete the selection animation before the keystroke arrives. Without the delay, the keystroke fires before Finder has focused the new file and is ignored.

---

## Notifications

User-facing errors are delivered via `UNUserNotificationCenter`. The extension requests `.alert` authorisation in `FinderSync.init()`:

```swift
UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
```

Notifications are fire-and-forget — the request is added to the notification center with a `UUID` identifier and no trigger (delivers immediately).

Error cases that show a notification:
- Clipboard contains no text (text-from-clipboard action)
- Clipboard contains no image (PNG-from-clipboard action)
- `data.write` throws (any action — filesystem permission failure, disk full, etc.)
