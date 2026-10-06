# Finder Sync Extension

## Version
Tracked in the `VERSION` file at the repo root, not in this doc — see [Distribution](06-distribution.md#versioning).

## What is a Finder Sync Extension?

A Finder Sync Extension is an app extension (`.appex` bundle) that plugs into Finder via the `com.apple.FinderSync` extension point. Apple introduced it in macOS 10.10 primarily for cloud-sync providers, but any app can use it to:

- **Badge files and folders** with status overlays (e.g. sync icons)
- **Add items to the Finder context menu** for monitored directories
- **Add a button to the Finder toolbar**

CorrectClick uses the context menu and the toolbar button. It does not badge files. The toolbar button exists because right-click menus don't work in cloud folders — see "Cloud folders" below.

---

## FIFinderSync lifecycle

The extension subclasses `FIFinderSync` from the `FinderSync` framework. macOS loads the extension as an XPC service hosted by Finder. The system controls the lifecycle — it may launch, suspend, or terminate the extension at any time independently of the parent app.

```swift
class FinderSyncExtension: FIFinderSync {
    override init() {
        super.init()
        // Must be called before anything else
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }
}
```

The `NSExtensionPrincipalClass` key in `Info.plist` points to this class:

```xml
<key>NSExtensionPrincipalClass</key>
<string>$(PRODUCT_MODULE_NAME).FinderSyncExtension</string>
```

At runtime this resolves to `CorrectClickExtension.FinderSyncExtension`, which is the Objective-C runtime name Swift uses for the class (module-prefixed).

---

## Directory monitoring

`FIFinderSyncController.default().directoryURLs` controls which directories the extension monitors. The context menu only appears when the user right-clicks within a monitored directory.

CorrectClick sets this to `/` (the filesystem root) so the menu appears everywhere:

```swift
FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
```

This is a standard pattern used by other Finder Sync extensions (e.g. OneDrive, Dropbox) that want global coverage.

---

## Context menu

`menu(for:)` is called by Finder whenever it needs to build a context menu for a monitored location. The `FIMenuKind` parameter indicates the context:

| Value | When it fires |
|---|---|
| `contextualMenuForItems` | User right-clicked selected file(s) |
| `contextualMenuForContainer` | User right-clicked the folder background |
| `toolbarItemMenu` | User clicked the toolbar button |

CorrectClick builds the same items for all kinds — the actions are equally valid whether the user right-clicked a file, the background of a folder, or the toolbar button. The only difference is wrapping: right-click menus put everything in a "CorrectClick" submenu (Finder shares that menu with every other extension), while the toolbar button's menu lists the items directly, since the button itself is already CorrectClick.

```swift
override func menu(for menuKind: FIMenuKind) -> NSMenu {
    let items = NSMenu(title: "CorrectClick")
    populate(items)
    if menuKind == .toolbarItemMenu { return items }

    let menu = NSMenu(title: "")
    let submenuItem = NSMenuItem(title: "CorrectClick", action: nil, keyEquivalent: "")
    submenuItem.submenu = items
    menu.addItem(submenuItem)
    return menu
}
```

---

## Cloud folders (iCloud Drive, OneDrive, Dropbox)

Since macOS Sonoma, Finder doesn't show **any** Finder Sync extension's right-click menu inside File Provider locations — iCloud Drive, and everything under `~/Library/CloudStorage` (current OneDrive, Dropbox, Google Drive, Box, …). This isn't a conflict with the provider's own extension and it isn't specific to CorrectClick; Apple has confirmed it's by design ([forum thread](https://developer.apple.com/forums/thread/718381), [another](https://developer.apple.com/forums/thread/737283)). Apple's suggested replacements (`FileProviderUI`, `NSFileProviderCustomAction`) only apply to a File Provider domain you own, so they can't add menus to someone else's cloud folder.

Finder Sync **toolbar buttons** are still shown in those locations, so CorrectClick provides one (`toolbarItemName` / `toolbarItemToolTip` / `toolbarItemImage` in `FinderSync.swift`). Users add it once via Finder's **View → Customize Toolbar…**; it opens the same menu for the current folder, and `targetedURL()` / `selectedItemURLs()` behave the same as for a right-click.

The returned `NSMenu` is a **submenu root** — Finder inserts its items into the context menu at the extension's designated position.

---

## Getting the target directory

When a menu action fires, `FIFinderSyncController.default().targetedURL()` returns the URL of the folder the user right-clicked in. This must be called synchronously within the action method — it is only valid during the menu callback.

```swift
@objc private func newTextFile() {
    guard let target = FIFinderSyncController.default().targetedURL() else { return }
    FileCreator.createTextFile(in: target)
}
```

---

## SourceKit false positives

SourceKit (the IDE's code intelligence engine) does not index the `FinderSync` framework outside of a full Xcode build. This means the editor shows errors for `FIFinderSync`, `FIFinderSyncController`, `FIMenuKind`, etc. These are **not real errors** — the project compiles and runs correctly. This is a known SourceKit limitation with private/restricted Apple frameworks.

---

## Registration and pluginkit

macOS tracks extensions through the `pluginkit` daemon. You can inspect extension state with:

```bash
pluginkit -m -A -v | grep CorrectClick
```

Status prefixes:
- `+` — enabled and healthy
- `-` — disabled by user
- `!` — registered but not yet approved (pending state)

On macOS 26, each new build binary gets a new UUID and is registered as a new instance in the pending (`!`) state even if the extension is already enabled in System Settings. The post-build script in `project.yml` handles this automatically:

```bash
pluginkit -e use -i "$BUNDLE_ID"
```

To force-reset all extension state (useful for debugging):

```bash
pluginkit -e ignore -i com.yourteam.CorrectClick.FinderSyncExtension
pluginkit -e use   -i com.yourteam.CorrectClick.FinderSyncExtension
killall Finder
```
