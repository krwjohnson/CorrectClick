## ✨ New in 1.0.5

### Toolbar button for iCloud Drive and OneDrive

macOS doesn't show right-click menus from extensions inside iCloud Drive or cloud-storage folders like OneDrive. CorrectClick now also has a **Finder toolbar button** with the same menu, which works everywhere, including those folders. Add it via **View → Customize Toolbar…** in Finder.

### Open at login

A new **Open CorrectClick at login** option in **Preferences → General** (off by default).

### More clipboard actions

| Action | Result |
|---|---|
| **New File from Clipboard (Auto-Detect)** | A `.webloc` for a URL, pretty-printed `.json` for JSON, otherwise `.txt` |
| **New JPG from Clipboard** | Clipboard image saved as a JPG (alongside the existing PNG action) |
| **New QR Code from Clipboard** | A QR code image of the clipboard's text |

### File Actions

A new section of the CorrectClick menu for acting on what's selected in Finder. Each action only appears when it makes sense for the current selection.

- **Copy POSIX Path / Shell-Escaped Path / `file://` URL / Markdown Link** (multiple items are copied one per line)
- **Copy as Base64** and **Copy File Hash (MD5 & SHA-256)**
- **Compress to ZIP** and **Extract ZIP**
- **Bulk Rename…** — find & replace or sequential numbering, with a preview before anything is renamed
- **Convert CSV to JSON** and **Convert JSON to CSV**
- **New Terminal Tab Here** — opens iTerm2 if installed, otherwise Terminal

All of them can be hidden or reordered in **Preferences → Menu Items**.

---

## 🐞 Fixes

- **Preferences, snippets, and your author name now save.** In 1.0.2 these changes were silently lost because of a sandbox permission error.
- **Adding a snippet no longer freezes the Preferences window.** Clicking Add could show an empty sheet with no way to close it.

---

## 🔧 Changes

- **New app icon.**
- **The Uninstall CorrectClick… menu item has been removed.** To uninstall, quit CorrectClick and drag it from Applications to the Trash.

---

## 💻 Requirements

- macOS 13 Ventura or later

---

## 📦 Installing and updating

- **Already have CorrectClick?** Choose **Check for Updates…** from the menu bar icon.
- **New install:** download the DMG below, drag **CorrectClick** to Applications, open it, and follow the welcome window to turn on the Finder extension.
