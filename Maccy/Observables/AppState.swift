import AppKit
import Defaults
import Foundation
import Settings
import SwiftData
import SwiftUI

@Observable
class AppState: Sendable {
  static let shared = AppState(history: History.shared, footer: Footer())

  let multiSelectionEnabled = false

  var appDelegate: AppDelegate?
  var popup: Popup
  var history: History
  var footer: Footer
  var navigator: NavigationManager
  var preview: SlideoutController

  var activeTab: ActiveTab = .history
  var drafts: [DraftItemDecorator] = []
  var selectedDraft: DraftItemDecorator?

  struct PreviewIdentity {
    let name: String
    let avatarDataURL: String
  }

  var previewIdentity: PreviewIdentity = AppState.loadPreviewIdentity()

  func reloadPreviewIdentity() {
    previewIdentity = AppState.loadPreviewIdentity()
  }

  private static func loadPreviewIdentity() -> PreviewIdentity {
    let svgString = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 36 36'><circle cx='18' cy='18' r='18' fill='#DDD'/><circle cx='18' cy='14' r='6' fill='#AAA'/><ellipse cx='18' cy='30' rx='11' ry='8' fill='#AAA'/></svg>"
    let genericAvatarURL = "data:image/svg+xml;base64,\(Data(svgString.utf8).base64EncodedString())"
    var name = "You"
    var avatarDataURL = genericAvatarURL
    let jsonURL = URL.applicationSupportDirectory.appending(path: "Maccy/preview-identity.json")
    struct Config: Decodable { let name: String?; let avatarPath: String? }
    if let data = try? Data(contentsOf: jsonURL),
       let config = try? JSONDecoder().decode(Config.self, from: data) {
      if let n = config.name, !n.isEmpty { name = n }
      if let path = config.avatarPath, let src = NSImage(contentsOfFile: path) {
        let size = NSSize(width: 36, height: 36)
        let resized = NSImage(size: size)
        resized.lockFocus()
        src.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1)
        resized.unlockFocus()
        if let tiff = resized.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let png = bitmap.representation(using: .png, properties: [:]) {
          avatarDataURL = "data:image/png;base64,\(png.base64EncodedString())"
        }
      }
    }
    return PreviewIdentity(name: name, avatarDataURL: avatarDataURL)
  }

  var searchVisible: Bool {
    if !Defaults[.showSearch] { return false }
    switch Defaults[.searchVisibility] {
    case .always: return true
    case .duringSearch: return !history.searchQuery.isEmpty
    }
  }

  var menuIconText: String {
    var title = history.unpinnedItems.first?.text.shortened(to: 100)
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    title.unicodeScalars.removeAll(where: CharacterSet.newlines.contains)
    return title.shortened(to: 20)
  }

  private let about = About()
  private var settingsWindowController: SettingsWindowController?

  init(history: History, footer: Footer) {
    self.history = history
    self.footer = footer
    popup = Popup()
    navigator = NavigationManager(history: history, footer: footer)
    preview = SlideoutController(
      onContentResize: { contentWidth in
        Defaults[.windowSize].width = contentWidth
      },
      onSlideoutResize: { previewWidth in
        Defaults[.previewWidth] = previewWidth
      })
    preview.contentWidth = Defaults[.windowSize].width
    preview.slideoutWidth = Defaults[.previewWidth]
  }

  @MainActor
  func select() {
    if !navigator.selection.isEmpty {
      if navigator.isMultiSelectInProgress {
        navigator.isManualMultiSelect = false
        history.startPasteStack(selection: &navigator.selection)
      } else {
        history.select(navigator.selection.first)
      }
    } else if let item = footer.selectedItem {
      // TODO: Use item.suppressConfirmation, but it's not updated!
      if item.confirmation != nil, Defaults[.suppressClearAlert] == false {
        item.showConfirmation = true
      } else {
        item.action()
      }
    } else {
      Clipboard.shared.copy(history.searchQuery)
      history.searchQuery = ""
    }
  }

  @MainActor
  func togglePin() {
    withTransaction(Transaction()) {
      navigator.selection.forEach { _, item in
        history.togglePin(item)
      }
    }
  }

  @MainActor
  func removePasteStack() {
    history.interruptPasteStack()
    navigator.highlightFirst()
  }

  @MainActor
  func deleteSelection() {
    guard let leadItem = navigator.leadHistoryItem else { return }
    let nextUnselectedItem = history.visibleItems.nearest(to: leadItem) { !$0.isSelected }

    withTransaction(Transaction()) {
      navigator.selection.forEach { _, item in
        history.delete(item)
      }
      navigator.select(item: nextUnselectedItem)
    }
  }

  func openAbout() {
    about.openAbout(nil)
  }

  @MainActor
  func openPreferences() { // swiftlint:disable:this function_body_length
    if settingsWindowController == nil {
      settingsWindowController = SettingsWindowController(
        panes: [
          Settings.Pane(
            identifier: Settings.PaneIdentifier.general,
            title: NSLocalizedString("Title", tableName: "GeneralSettings", comment: ""),
            toolbarIcon: NSImage.gearshape!
          ) {
            GeneralSettingsPane()
          },
          Settings.Pane(
            identifier: Settings.PaneIdentifier.storage,
            title: NSLocalizedString("Title", tableName: "StorageSettings", comment: ""),
            toolbarIcon: NSImage.externaldrive!
          ) {
            StorageSettingsPane()
          },
          Settings.Pane(
            identifier: Settings.PaneIdentifier.appearance,
            title: NSLocalizedString("Title", tableName: "AppearanceSettings", comment: ""),
            toolbarIcon: NSImage.paintpalette!
          ) {
            AppearanceSettingsPane()
          },
          Settings.Pane(
            identifier: Settings.PaneIdentifier.pins,
            title: NSLocalizedString("Title", tableName: "PinsSettings", comment: ""),
            toolbarIcon: NSImage.pincircle!
          ) {
            PinsSettingsPane()
              .environment(self)
              .modelContainer(Storage.shared.container)
          },
          Settings.Pane(
            identifier: Settings.PaneIdentifier.ignore,
            title: NSLocalizedString("Title", tableName: "IgnoreSettings", comment: ""),
            toolbarIcon: NSImage.nosign!
          ) {
            IgnoreSettingsPane()
          },
          Settings.Pane(
            identifier: Settings.PaneIdentifier.drafts,
            title: "Drafts",
            toolbarIcon: NSImage.squareAndPencil!
          ) {
            DraftsSettingsPane()
          },
          Settings.Pane(
            identifier: Settings.PaneIdentifier.advanced,
            title: NSLocalizedString("Title", tableName: "AdvancedSettings", comment: ""),
            toolbarIcon: NSImage.gearshape2!
          ) {
            AdvancedSettingsPane()
          }
        ]
      )
    }
    settingsWindowController?.show()
    settingsWindowController?.window?.orderFrontRegardless()
  }

  @MainActor
  func selectDraft(_ draft: DraftItemDecorator) {
    let board = NSPasteboard.general
    board.clearContents()
    if let data = draft.html.data(using: .utf8) {
      board.setData(data, forType: .html)
    }
    if let plain = draft.plain {
      board.setString(plain, forType: .string)
    }
    board.setString("", forType: .fromMaccy)
    popup.close()
  }

  @MainActor
  func hoverDraft(_ draft: DraftItemDecorator) {
    selectedDraft = draft
    preview.resetAutoOpenSuppression()
    preview.startAutoOpen()
  }

  @MainActor
  func deleteSelectedDraft() {
    guard let draft = selectedDraft else { return }
    let context = Storage.shared.context
    let id = draft.draftId
    if let item = try? context.fetch(FetchDescriptor<DraftItem>(
      predicate: #Predicate { $0.id == id }
    )).first {
      context.delete(item)
      try? context.save()
    }
    let fileURL = DraftWatcher.draftsDir.appending(path: "\(id).json")
    try? FileManager.default.removeItem(at: fileURL)
    drafts.removeAll { $0.id == draft.id }
    selectedDraft = drafts.first
  }

  func quit() {
    NSApp.terminate(self)
  }
}

enum ActiveTab {
  case history
  case drafts
}
