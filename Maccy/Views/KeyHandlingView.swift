import Sauce
import Defaults
import SwiftUI

struct KeyHandlingView<Content: View>: View {
  @Binding var searchQuery: String
  @FocusState.Binding var searchFocused: Bool
  @ViewBuilder let content: () -> Content

  @Environment(AppState.self) private var appState

  var body: some View {
    content()
      .onKeyPress { _ in
        // Unfortunately, key presses don't allow access to
        // key code and don't properly work with multiple inputs,
        // so pressing ⌘, on non-English layout doesn't open
        // preferences. Stick to NSEvent to fix this behavior.

        if searchFocused {
          // Ignore input when candidate window is open
          // https://stackoverflow.com/questions/73677444/how-to-detect-the-candidate-window-when-using-japanese-keyboard
          if let inputClient = NSApp.keyWindow?.firstResponder as? NSTextInputClient,
             inputClient.hasMarkedText() {
            return .ignored
          }
        }

        // Tab toggle (⌘D) — works from either tab
        if case .switchTab = KeyChord(NSApp.currentEvent) {
          let newTab: ActiveTab = appState.activeTab == .history ? .drafts : .history
          appState.activeTab = newTab
          appState.selectedDraft = nil
          if newTab == .drafts {
            appState.preview.slideoutWidth = max(appState.preview.slideoutWidth, 400)
          }
          return .handled
        }

        // Draft tab key handling
        if appState.activeTab == .drafts {
          switch KeyChord(NSApp.currentEvent) {
          case .selectCurrentItem:
            if let draft = appState.selectedDraft {
              appState.selectDraft(draft)
            }
            return .handled
          case .deleteCurrentItem:
            appState.deleteSelectedDraft()
            return .handled
          case .moveToNext:
            if let current = appState.selectedDraft,
               let idx = appState.drafts.firstIndex(where: { $0.id == current.id }),
               idx + 1 < appState.drafts.count {
              appState.hoverDraft(appState.drafts[idx + 1])
            } else if appState.selectedDraft == nil, let first = appState.drafts.first {
              appState.hoverDraft(first)
            }
            return .handled
          case .moveToPrevious:
            if let current = appState.selectedDraft,
               let idx = appState.drafts.firstIndex(where: { $0.id == current.id }),
               idx > 0 {
              appState.hoverDraft(appState.drafts[idx - 1])
            }
            return .handled
          case .close:
            appState.popup.close()
            return .handled
          case .togglePreview:
            appState.preview.togglePreview()
            return .handled
          case .openPreferences:
            appState.openPreferences()
            return .handled
          default:
            // ⌘+number selects Nth draft
            if let event = NSApp.currentEvent,
               event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
               let char = event.charactersIgnoringModifiers,
               let digit = Int(char), digit >= 1 {
              let idx = digit - 1
              if idx < appState.drafts.count {
                appState.selectDraft(appState.drafts[idx])
              }
              return .handled
            }
            return .ignored
          }
        }

        switch KeyChord(NSApp.currentEvent) {
        case .clearHistory:
          if let item = appState.footer.items.first(where: { $0.title == "clear" }),
             item.confirmation != nil,
             let suppressConfirmation = item.suppressConfirmation {
            if suppressConfirmation.wrappedValue {
              item.action()
            } else {
              item.showConfirmation = true
            }
            return .handled
          } else {
            return .ignored
          }
        case .clearHistoryAll:
          if let item = appState.footer.items.first(where: { $0.title == "clear_all" }),
             item.confirmation != nil,
             let suppressConfirmation = item.suppressConfirmation {
            if suppressConfirmation.wrappedValue {
              item.action()
            } else {
              item.showConfirmation = true
            }
            return .handled
          } else {
            return .ignored
          }
        case .clearSearch:
          searchQuery = ""
          return .handled
        case .deleteCurrentItem:
          if appState.navigator.pasteStackSelected {
            appState.removePasteStack()
          } else {
            appState.deleteSelection()
          }
          return .handled
        case .deleteOneCharFromSearch:
          searchFocused = true
          _ = searchQuery.popLast()
          return .handled
        case .deleteLastWordFromSearch:
          searchFocused = true
          let newQuery = searchQuery.split(separator: " ").dropLast().joined(separator: " ")
          if newQuery.isEmpty {
            searchQuery = ""
          } else {
            searchQuery = "\(newQuery) "
          }

          return .handled
        case .moveToNext:
          guard NSApp.characterPickerWindow == nil else {
            return .ignored
          }

          appState.navigator.highlightNext()
          return .handled
        case .moveToLast:
          guard NSApp.characterPickerWindow == nil else {
            return .ignored
          }

          appState.navigator.highlightLast()
          return .handled
        case .moveToPrevious:
          guard NSApp.characterPickerWindow == nil else {
            return .ignored
          }

          appState.navigator.highlightPrevious()
          return .handled
        case .moveToFirst:
          guard NSApp.characterPickerWindow == nil else {
            return .ignored
          }

          appState.navigator.highlightFirst()
          return .handled
        case .extendToNext:
          guard NSApp.characterPickerWindow == nil else {
            return .ignored
          }
          guard AppState.shared.multiSelectionEnabled else {
            return .ignored
          }
          appState.navigator.extendHighlightToNext()
          return .handled
        case .extendToLast:
          guard NSApp.characterPickerWindow == nil else {
            return .ignored
          }
          guard AppState.shared.multiSelectionEnabled else {
            return .ignored
          }
          appState.navigator.extendHighlightToLast()
          return .handled
        case .extendToPrevious:
          guard NSApp.characterPickerWindow == nil else {
            return .ignored
          }
          guard AppState.shared.multiSelectionEnabled else {
            return .ignored
          }
          appState.navigator.extendHighlightToPrevious()
          return .handled
        case .extendToFirst:
          guard NSApp.characterPickerWindow == nil else {
            return .ignored
          }
          guard AppState.shared.multiSelectionEnabled else {
            return .ignored
          }
          appState.navigator.extendHighlightToFirst()
          return .handled
        case .openPreferences:
          appState.openPreferences()
          return .handled
        case .pinOrUnpin:
          appState.togglePin()
          return .handled
        case .selectCurrentItem:
          appState.select()
          return .handled
        case .close:
          appState.popup.close()
          return .handled
        case .togglePreview:
          appState.preview.togglePreview()
          return .handled
        default:
          ()
        }

        if let item = appState.history.pressedShortcutItem {
          appState.navigator.select(item: item)
          Task {
            try? await Task.sleep(for: .milliseconds(50))
            appState.history.select(item)
          }
          return .handled
        }

        return .ignored
      }
  }
}
