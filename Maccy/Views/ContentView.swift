import SwiftData
import SwiftUI

struct ContentView: View {
  @State private var appState = AppState.shared
  @State private var modifierFlags = ModifierFlags()
  @State private var scenePhase: ScenePhase = .background

  @FocusState private var searchFocused: Bool

  var body: some View {
    ZStack {
      if #available(macOS 26.0, *) {
        GlassEffectView()
      } else {
        VisualEffectView()
      }

      KeyHandlingView(searchQuery: $appState.history.searchQuery, searchFocused: $searchFocused) {
        VStack(spacing: 0) {
          SlideoutView(controller: appState.preview) {
            HeaderView(
              controller: appState.preview,
              searchFocused: $searchFocused
            )

            if appState.activeTab == .history {
              VStack(alignment: .leading, spacing: 0) {
                HistoryListView(
                  searchQuery: $appState.history.searchQuery,
                  searchFocused: $searchFocused
                )

                FooterView(footer: appState.footer)
              }
              .animation(.default.speed(3), value: appState.history.items)
              .animation(
                .default.speed(3),
                value: appState.history.pasteStack?.id
              )
              .padding(.horizontal, Popup.horizontalPadding)
              .onAppear {
                searchFocused = true
              }
              .onMouseMove {
                appState.navigator.isKeyboardNavigating = false
              }
            } else {
              DraftListView()
                .padding(.horizontal, Popup.horizontalPadding)
            }
          } slideout: {
            SlideoutContentView()
          }
          .frame(minHeight: 0)
          .layoutPriority(1)

          // Tab switcher
          Picker("", selection: Binding(
            get: { appState.activeTab },
            set: {
              appState.activeTab = $0
              appState.selectedDraft = nil
              if $0 == .drafts {
                appState.preview.slideoutWidth = max(appState.preview.slideoutWidth, 400)
              }
            }
          )) {
            Text("History").tag(ActiveTab.history)
            Text("Drafts").tag(ActiveTab.drafts)
          }
          .pickerStyle(.segmented)
          .padding(.horizontal, Popup.horizontalPadding * 2)
          .padding(.vertical, 6)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .task {
        try? await appState.history.load()
      }
    }
    .animation(.easeInOut(duration: 0.2), value: appState.searchVisible)
    .environment(appState)
    .environment(modifierFlags)
    .environment(\.scenePhase, scenePhase)
    // FloatingPanel is not a scene, so let's implement custom scenePhase..
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) {
      if let window = $0.object as? NSWindow,
         let bundleIdentifier = Bundle.main.bundleIdentifier,
         window.identifier == NSUserInterfaceItemIdentifier(bundleIdentifier) {
        scenePhase = .active
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) {
      if let window = $0.object as? NSWindow,
         let bundleIdentifier = Bundle.main.bundleIdentifier,
         window.identifier == NSUserInterfaceItemIdentifier(bundleIdentifier) {
        scenePhase = .background
      }
    }
  }
}

#Preview {
  ContentView()
    .environment(\.locale, .init(identifier: "en"))
    .modelContainer(Storage.shared.container)
}
