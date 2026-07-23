import Sauce
import SwiftUI

struct DraftListView: View {
  @Environment(AppState.self) private var appState

  var body: some View {
    if appState.drafts.isEmpty {
      Text("No drafts yet")
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 20)
        .padding(.horizontal, Popup.horizontalPadding)
    } else {
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(Array(appState.drafts.enumerated()), id: \.element.id) { index, draft in
            DraftItemRow(draft: draft, index: index)
          }
        }
        .padding(.vertical, Popup.verticalSeparatorPadding)
      }
      .onAppear {
        if appState.selectedDraft == nil, let first = appState.drafts.first {
          appState.selectedDraft = first
        }
      }
    }
  }
}

private struct DraftItemRow: View {
  let draft: DraftItemDecorator
  let index: Int
  @Environment(AppState.self) private var appState

  private var isSelected: Bool {
    appState.selectedDraft?.id == draft.id
  }

  private var shortcut: KeyShortcut? {
    guard index < 9 else { return nil }
    let digits = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
    let key = Key(character: digits[index], virtualKeyCode: nil)
    return KeyShortcut(key: key, modifierFlags: [.command])
  }

  var body: some View {
    ListItemView(
      id: draft.id,
      selectionId: draft.id,
      appIcon: nil,
      image: nil,
      accessoryImage: nil,
      attributedTitle: nil,
      shortcuts: shortcut.map { [$0] } ?? [],
      isSelected: isSelected,
      selectionIndex: nil
    ) {
      Text(draft.displayTitle)
    }
    .onTapGesture {
      appState.selectDraft(draft)
    }
    .onHover { hovering in
      if hovering {
        appState.hoverDraft(draft)
      }
    }
  }
}
