import AppKit
import SwiftUI

struct DraftPreviewView: NSViewRepresentable {
  let html: String
  let identity: AppState.PreviewIdentity

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSTextView.scrollableTextView()
    if let tv = scrollView.documentView as? NSTextView {
      tv.isEditable = false
      tv.isSelectable = true
      tv.drawsBackground = true
      tv.backgroundColor = NSColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1)
      tv.textContainerInset = NSSize(width: 0, height: 0)
    }
    scrollView.drawsBackground = true
    scrollView.backgroundColor = NSColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1)
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let tv = scrollView.documentView as? NSTextView else { return }
    guard let data = styledHTML.data(using: .utf8),
          let parsed = try? NSAttributedString(
            data: data,
            options: [
              .documentType: NSAttributedString.DocumentType.html,
              .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
          ) else { return }

    let mutable = NSMutableAttributedString(attributedString: parsed)
    let fullRange = NSRange(location: 0, length: mutable.length)
    mutable.enumerateAttribute(.font, in: fullRange) { value, range, _ in
      guard let font = value as? NSFont else { return }
      let traits = font.fontDescriptor.symbolicTraits
      let size = max(font.pointSize, 13)
      let newFont: NSFont
      if traits.contains(.monoSpace) {
        newFont = NSFont.monospacedSystemFont(ofSize: size - 1, weight: traits.contains(.bold) ? .bold : .regular)
      } else if traits.contains(.bold) {
        newFont = NSFont.boldSystemFont(ofSize: size)
      } else {
        newFont = NSFont.systemFont(ofSize: size)
      }
      mutable.addAttribute(.font, value: newFont, range: range)
    }

    tv.textStorage?.setAttributedString(mutable)
  }

  private var styledHTML: String {
    let initial = identity.name.first.map(String.init) ?? "?"
    let avatarTag = identity.avatarDataURL.isEmpty
      ? "<div class='avatar'>\(initial)</div>"
      : "<img src='\(identity.avatarDataURL)' class='avatar' />"

    let preprocessed = html
      .replacingOccurrences(of: "<ul>", with: "")
      .replacingOccurrences(of: "</ul>", with: "")
      .replacingOccurrences(of: "<ol>", with: "")
      .replacingOccurrences(of: "</ol>", with: "")
      .replacingOccurrences(of: "<li>", with: "<p style='margin:0 0 3px 0'>• ")
      .replacingOccurrences(of: "</li>", with: "</p>")

    return """
    <!DOCTYPE html><html><head><meta charset='utf-8'>
    <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: Helvetica Neue, Helvetica, Arial, sans-serif;
           font-size: 14px; line-height: 1.46; color: #1d1c1d;
           background: #f8f8f8; padding: 12px 14px; }
    .msg { display: flex; gap: 10px; }
    .avatar { width: 36px; height: 36px; border-radius: 6px;
              flex-shrink: 0; object-fit: cover; }
    div.avatar { background: #611f69; display: flex; align-items: center;
                 justify-content: center; color: #fff; font-weight: 700; font-size: 16px; }
    .right { flex: 1; min-width: 0; }
    .header { display: flex; align-items: baseline; gap: 7px; margin-bottom: 3px; }
    .name { font-weight: 700; font-size: 15px; color: #1d1c1d; }
    .ts { font-size: 12px; color: #888; }
    p { margin: 0 0 4px 0; }
    strong { font-weight: 700; }
    em { font-style: italic; }
    del { text-decoration: line-through; color: #666; }
    code { font-family: Menlo, Monaco, monospace; font-size: 12px;
           background: rgba(29,28,29,.08); border-radius: 3px;
           padding: 1px 5px; }
    pre { font-family: Menlo, Monaco, monospace; font-size: 12px;
          background: #f0f0f0; border-left: 3px solid #ccc;
          padding: 8px 10px; border-radius: 0 4px 4px 0;
          white-space: pre-wrap; word-break: break-word; margin: 6px 0; }
    pre code { background: none; padding: 0; border-radius: 0; }
    a { color: #1264a3; text-decoration: none; }
    a:hover { text-decoration: underline; }
    </style>
    </head><body>
    <div class='msg'>
      \(avatarTag)
      <div class='right'>
        <div class='header'>
          <span class='name'>\(identity.name)</span>
          <span class='ts'>Today</span>
        </div>
        <div class='body'>\(preprocessed)</div>
      </div>
    </div>
    </body></html>
    """
  }
}
