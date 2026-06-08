import SwiftUI

struct SlideoutContentView: View {
  @Environment(AppState.self) var appState

  var body: some View {
    VStack {
      ToolbarView()

      if appState.activeTab == .drafts {
        if let draft = appState.selectedDraft {
          DraftPreviewView(html: draft.html, identity: appState.previewIdentity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          EmptyView()
        }
      } else if let item = appState.navigator.leadHistoryItem {
        PreviewItemView(item: item)
      } else if let pasteStack = appState.history.pasteStack,
        appState.navigator.pasteStackSelected {
        PasteStackPreviewView(pasteStack: pasteStack)
      } else {
        EmptyView()
      }
    }
    .padding(.horizontal)
    .padding(.bottom)
    .padding(.top, Popup.verticalPadding)
  }

}
