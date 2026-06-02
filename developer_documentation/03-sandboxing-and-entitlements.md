# Sandboxing and Entitlements

## Version
1.0.0

## Overview

CorrectClick has two targets with different sandboxing requirements. macOS enforces that all app extensions (`.appex`) must be sandboxed — this is a hard system requirement, not an App Store-only rule.

---

## Parent app entitlements

**File:** `CorrectClick/CorrectClick.entitlements`

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
```

The parent app only needs a basic sandbox. It opens a URL to System Settings on first launch (`NSWorkspace.shared.open`) which is allowed without any additional entitlements.

---

## Extension entitlements

**File:** `CorrectClickExtension/CorrectClickExtension.entitlements`

```xml
<key>com.apple.security.app-sandbox</key>
<true/>

<key>com.apple.security.temporary-exception.files.absolute-path.read-write</key>
<array>
    <string>/</string>
</array>
```

### Why the temporary exception?

The extension needs to **write files to arbitrary directories** — wherever the user right-clicks. The standard sandbox entitlements only cover explicitly user-selected paths (via `NSOpenPanel`) or known folders like Downloads. Neither applies here because the user is right-clicking, not using a file picker.

`temporary-exception.files.absolute-path.read-write` with the path `/` grants the sandboxed extension read-write access to the entire filesystem. It is a temporary exception in the sense that it is not a standard sandbox capability — it requires explicit approval in the entitlements.

### Distribution implications

| Distribution method | This entitlement allowed? |
|---|---|
| Direct download (notarised) | ✅ Yes |
| Mac App Store | ❌ No |

For App Store distribution, the architecture would need to change: the extension would communicate with the parent app via XPC, and the parent app would hold user-selected file access and perform the actual writes. The extension would only coordinate the UI.

### What about `com.apple.security.app-sandbox = false`?

Setting sandbox to `false` on the extension was tried early in development. macOS rejects it at load time with:

> plug-ins must be sandboxed

The extension must be sandboxed. The temporary exception is the correct way to get broad filesystem access within a sandboxed extension for direct-download distribution.

---

## CGEvent posting

The rename-mode trigger in `FileCreator.swift` posts a Return key `CGEvent` to the session event tap:

```swift
CGEvent(keyboardEventSource: src, virtualKey: 0x24, keyDown: true)?.post(tap: .cgSessionEventTap)
```

This does **not** require the Accessibility permission or any special entitlement when used from a sandboxed extension that does not have the `com.apple.security.automation.apple-events` entitlement. Posting to `.cgSessionEventTap` sends the event to whatever app is currently frontmost — in this case Finder, which was brought to front by `NSWorkspace.shared.activateFileViewerSelecting` immediately before.

---

## Hardened Runtime

Both targets have `ENABLE_HARDENED_RUNTIME = YES`. This is required for notarisation. The hardened runtime restricts JIT compilation, unsigned executable memory, and dyld environment variables, none of which CorrectClick uses, so no hardened runtime exceptions are needed.
