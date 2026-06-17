# Errors

## WKWebView blank in NSPanel (.nonActivatingPanel)

**What failed:** `WKWebView` consistently rendered blank (white rectangle) when hosted inside Maccy's `FloatingPanel` (`NSPanel` with `.nonActivatingPanel` style mask). Tried: delayed `loadHTMLString` via `DispatchQueue.main.asyncAfter`, giving the view a non-zero frame before insertion, calling `needsDisplay + display()` in `WKNavigationDelegate.webView(_:didFinish:)`, `drawsBackground = false`. None reliably rendered content.

**Why:** WKWebView runs in a separate web content process. A non-activating panel never becomes key window, so the web process throttles or never initializes rendering. The panel looks "active" from the app's perspective but the OS treats it as background for web rendering purposes.

**What worked instead:** `NSTextView` via `NSTextView.scrollableTextView()` with `NSAttributedString` HTML parsing (`NSAttributedString.DocumentType.html`). Renders inline in the app process, no separate web content process, works in non-activating panels.

**Limitations of NSAttributedString HTML:** No CSS overflow/scroll, limited CSS support. `<ul><li>` stacks its own bullet glyphs on top of CSS bullets — must preprocess HTML to replace list markup with `<p>• </p>` paragraphs. `NSAttributedString` ignores CSS `font-family` — must post-process attributed string with `enumerateAttribute(.font)` to replace fonts with system fonts. CSS `width`/`height` on `<img>` is ignored — resize the image in Swift (`NSImage` resize + PNG re-encode) before base64-encoding to get correct dimensions.

**Note for next time:** Don't retry WKWebView in a non-activating panel without first finding a confirmed workaround for the web content process throttle. The `NSAttributedString` approach is good enough for rich-text preview.

---

## `DispatchSource.makeFileSystemObjectSource` — atomic write fires `.rename` not `.write`

**What failed:** `DraftWatcher` used `.write` event mask to detect changes to `drafts.json`. Claude's `Write` tool does an atomic write (writes temp file, renames into place), which fires `.rename`/`.delete` on the watched fd — not `.write`. The watcher re-armed after rename but didn't call `ingest()`.

**What worked instead:** Handle `.delete` and `.rename` events in the event handler: cancel the source, asyncAfter 0.1s to re-open the new fd, then call `ingest()` after re-arming.

---

## Maccy sandbox — `URL.applicationSupportDirectory` resolves to container, not `~/Library/Application Support/`

**What failed:** Wrote `drafts.json` to `~/Library/Application Support/Maccy/` — Maccy never picked it up.

**Why:** Maccy is sandboxed (`com.apple.security.app-sandbox = true`). Inside the sandbox, `URL.applicationSupportDirectory` resolves to `~/Library/Containers/org.p0deje.Maccy/Data/Library/Application Support/`. Writes to the unsandboxed path are invisible to the app.

**Correct path:** `~/Library/Containers/org.p0deje.Maccy/Data/Library/Application Support/Maccy/`

**Note for next time:** All Maccy runtime files (drafts.json, avatar.png, preview-identity.json) must be written to the container path, not the bare `~/Library/Application Support/Maccy/` path. The CLAUDE.md Slack Drafts section documents this.

---

## pbxproj registration required for new Swift files

**What failed (potential):** New Swift files exist on disk but are not compiled unless registered in `Maccy.xcodeproj/project.pbxproj` with entries in `PBXBuildFile`, `PBXFileReference`, the appropriate `PBXGroup`, and the `PBXSourcesBuildPhase` (`DAEE383F1E3DBEB100DD2966`).

**Pattern:** Use unique hex IDs (e.g., `CC1F00XX2CF000010000001A`) not already present in the pbxproj. Add 4 entries per file: build file entry, file reference entry, group child entry, sources phase entry.

---

## Preview identity as `static var` — doesn't update without restart

**What failed:** `DraftPreviewView` stored `PreviewIdentity` as a `private static var` computed once at first use. When the user changed their name/avatar in the Drafts settings pane and saved, the running app still showed the old identity.

**Why:** Swift lazy `static var` semantics — evaluated once per process lifetime, cached forever. Writing to `preview-identity.json` after the static was already initialized had no effect.

**What worked instead:** Move identity into `AppState` as a regular `var previewIdentity: PreviewIdentity` with a `reloadPreviewIdentity()` method. `DraftsSettingsPane.save()` calls `AppState.shared.reloadPreviewIdentity()` after writing the file. `DraftPreviewView` receives identity as an init parameter from `SlideoutContentView`, which reads it from `appState.previewIdentity`. Since `AppState` is `@Observable`, SwiftUI re-renders the preview immediately.

---

## `DraftWatcher.ingest()` silently ignores updates to existing drafts

**What failed:** When Claude writes a draft with an existing `id` (e.g. to update content), Maccy doesn't pick up the change. The draft in the Drafts tab still shows the old content.

**Why:** `ingest()` only inserts payloads whose `id` is not already in `existingIds` (line 104: `for payload in payloads where !existingIds.contains(payload.id)`). If a draft already exists with the same id, any changes to `html`, `label`, or `plain` are silently skipped.

**Fix:** Change the insert loop to upsert — if the id already exists, fetch the `DraftItem` and update its fields. If it doesn't exist, insert it. The delete loop (removing items no longer in the JSON) is correct and should stay.

**Note for next time:** The fix is entirely in `DraftWatcher.ingest()` — no other files need changing.

---

## `NSAttributedString` HTML list rendering double-bullets

**What failed:** `<ul><li>` in HTML passed to `NSAttributedString` HTML parser produces double bullets — the parser adds its own `NSTextList` bullet on top of whatever CSS bullet character is specified.

**Fix:** Preprocess HTML before parsing: strip `<ul>`, `</ul>`, `<ol>`, `</ol>`, replace `<li>` with `<p style='margin:0 0 3px 0'>• `, replace `</li>` with `</p>`. This bypasses the NSTextList renderer entirely.
