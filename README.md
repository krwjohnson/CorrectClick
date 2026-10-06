# CorrectClick

Right-click in Finder to create new files, turn your clipboard into a file, and run quick actions on selected files — no app windows, no dialogs.

---

## What it does

CorrectClick adds a **CorrectClick** submenu to the Finder right-click menu. Every item can be hidden or reordered in **Preferences → Menu Items**.

### New File

New Text, JSON, Python, CSV, Markdown, YAML, HTML, TOML, XML, Swift, SQL, and `.plist` files, plus a Shell Script (created executable), `.gitignore`, `LICENSE`, `.env`, and `Dockerfile`.

New files are named `Untitled` and pick up a number if that name is taken (`Untitled 2`, `Untitled 3`, …). The file is selected in Finder and put straight into rename mode — just like creating a new folder.

### From Clipboard

| Action | What it creates |
|---|---|
| **New Text File from Clipboard** | A `.txt` file with the clipboard's text |
| **New PNG / JPG from Clipboard** | An image file from a copied image or screenshot |
| **New File from Clipboard (Auto-Detect)** | A `.webloc` for a URL, pretty-printed `.json` for JSON, otherwise `.txt` |
| **New QR Code from Clipboard** | A QR code image of the clipboard's text |

### Snippets

Define your own "New … File" entries in **Preferences → Snippets**: a name, a file extension, and starter content. Starter content can include placeholders that are filled in when the file is created:

`{{date}}` `{{time}}` `{{datetime}}` `{{filename}}` `{{clipboard}}` `{{author}}`

Set your `{{author}}` name on the **General** tab. Snippets can be exported to and imported from a JSON file.

> `{{filename}}` is the name the file is created with (e.g. `Untitled 2`), not the name you rename it to afterwards.

### File Actions

These appear only when they make sense for what's selected in Finder:

| Action | Shown when |
|---|---|
| **Copy POSIX Path / Shell-Escaped Path / `file://` URL / Markdown Link** | One or more items selected (multiple are joined one per line) |
| **Compress to ZIP** | One or more items selected |
| **Bulk Rename…** | One or more items selected — find & replace or sequential numbering, with a preview before anything changes |
| **Copy as Base64** | Exactly one file selected |
| **Copy File Hash (MD5 & SHA-256)** | Exactly one file selected |
| **Extract ZIP** | A single `.zip` selected |
| **Convert CSV to JSON** | A single `.csv` selected |
| **Convert JSON to CSV** | A single `.json` selected |
| **New Terminal Tab Here** | Always — opens iTerm2 if installed, otherwise Terminal |

---

## Requirements

- macOS 13 Ventura or later

---

## Installation

1. Download the latest `CorrectClick-X.Y.Z.dmg` from [Releases](https://github.com/krwjohnson/CorrectClick/releases)
2. Open it and drag **CorrectClick** to your Applications folder
3. Open CorrectClick from Applications — a welcome window walks you through enabling the Finder extension
4. Click **Open Extensions Settings** in that window and turn on **CorrectClick** in the list that appears
   - To find it yourself: on macOS 15 and later, **General → Login Items & Extensions**, then the Finder / File Providers extensions list; on macOS 13–14, **Privacy & Security → Extensions → Added Extensions**

CorrectClick lives in your menu bar (no Dock icon). From there you can re-open the extension setup, open **Preferences…**, or **Check for Updates…**.

To start CorrectClick automatically, turn on **Open CorrectClick at login** in **Preferences → General**. The Finder menu works either way; this just keeps the menu bar icon and update checks running.

The first time you use **New Terminal Tab Here**, macOS asks for permission for CorrectClick to control Terminal or iTerm2.

---

## Usage

Right-click any folder, file, or empty space in a Finder window and open the **CorrectClick** submenu — or click the CorrectClick toolbar button (see below).

> **Tip:** The clipboard actions show a notification if your clipboard doesn't contain the right kind of content.

### iCloud Drive, OneDrive, and other cloud folders

macOS doesn't show right-click menus from extensions inside iCloud Drive or cloud-storage folders (OneDrive, Dropbox, Google Drive, and so on). This affects every Finder extension, not just CorrectClick.

Use the **CorrectClick toolbar button** there instead: in Finder, choose **View → Customize Toolbar…** and drag the CorrectClick button into the toolbar. Clicking it opens the same menu for the folder you're in, and it works everywhere — not just in cloud folders.

---

## Updates

CorrectClick checks for updates automatically once a day. Turn this off, or check manually, in **Preferences → Updates** or from the menu bar icon.

---

## Uninstalling

Choose **Quit CorrectClick** from the menu bar icon, then drag **CorrectClick** from Applications to the Trash. That removes the app and its Finder extension. Finder may keep showing the menu until you empty the Trash or restart Finder.

Like most Mac apps, CorrectClick leaves a few kilobytes of settings behind, so your menu choices and snippets come back if you reinstall. To remove those too, delete these folders:

- `~/Library/Application Support/CorrectClick`
- `~/Library/Containers/com.correctclick.CorrectClick`
- `~/Library/Containers/com.correctclick.CorrectClick.FinderSyncExtension`

---

## Privacy

CorrectClick doesn't collect any data or require an account. All file actions run locally on your Mac.

The only network access is the update check: once a day (unless you turn it off), CorrectClick fetches its update feed from GitHub, and downloads a new version from GitHub Releases if you choose to install it.
