import SwiftUI
import Settings
import UniformTypeIdentifiers

struct DraftsSettingsPane: View {
  @State private var name: String = ""
  @State private var avatarPath: String = ""
  @State private var avatarImage: NSImage?
  @State private var showFilePicker = false
  @State private var savedName: String = ""
  @State private var savedAvatarPath: String = ""
  @State private var showSavedConfirmation = false

  private let identityURL = URL.applicationSupportDirectory.appending(path: "Maccy/preview-identity.json")
  private let containerDir = URL.applicationSupportDirectory.appending(path: "Maccy")

  private var isDirty: Bool {
    name != savedName || avatarPath != savedAvatarPath
  }

  var body: some View {
    Settings.Container(contentWidth: 450) {
      Settings.Section(label: { Text("Preview Identity") }) {
        HStack(spacing: 12) {
          avatarThumbnail

          VStack(alignment: .leading, spacing: 6) {
            TextField("Display name", text: $name)
              .textFieldStyle(.roundedBorder)
              .frame(width: 220)
              .onSubmit { save() }

            Button("Choose Avatar...") { showFilePicker = true }
              .controlSize(.small)
          }
        }

        Text("Shown in the Drafts preview pane. Takes effect after restarting Maccy.")
          .controlSize(.small)
          .foregroundStyle(.secondary)

        HStack {
          if showSavedConfirmation {
            Label("Saved", systemImage: "checkmark.circle.fill")
              .foregroundStyle(.green)
              .controlSize(.small)
              .transition(.opacity)
          }
          Spacer()
          Button("Save") { save() }
            .keyboardShortcut(.defaultAction)
            .disabled(!isDirty)
        }
        .animation(.easeInOut(duration: 0.2), value: showSavedConfirmation)
      }
    }
    .onAppear(perform: load)
    .fileImporter(
      isPresented: $showFilePicker,
      allowedContentTypes: [.png, .jpeg, .heic],
      allowsMultipleSelection: false
    ) { result in
      guard case .success(let urls) = result, let url = urls.first else { return }
      guard url.startAccessingSecurityScopedResource() else { return }
      defer { url.stopAccessingSecurityScopedResource() }
      importAvatar(from: url)
    }
  }

  private var avatarThumbnail: some View {
    Group {
      if let img = avatarImage {
        Image(nsImage: img)
          .resizable()
          .frame(width: 44, height: 44)
          .clipShape(RoundedRectangle(cornerRadius: 8))
      } else {
        RoundedRectangle(cornerRadius: 8)
          .fill(Color(nsColor: .quaternaryLabelColor))
          .frame(width: 44, height: 44)
          .overlay(
            Image(systemName: "person.fill")
              .foregroundStyle(.secondary)
          )
      }
    }
  }

  private func load() {
    struct Config: Decodable { let name: String?; let avatarPath: String? }
    guard let data = try? Data(contentsOf: identityURL),
          let config = try? JSONDecoder().decode(Config.self, from: data) else { return }
    name = config.name ?? ""
    avatarPath = config.avatarPath ?? ""
    savedName = name
    savedAvatarPath = avatarPath
    if !avatarPath.isEmpty {
      avatarImage = NSImage(contentsOfFile: avatarPath)
    }
  }

  private func save() {
    try? FileManager.default.createDirectory(at: containerDir, withIntermediateDirectories: true)
    var dict: [String: String] = [:]
    if !name.isEmpty { dict["name"] = name }
    if !avatarPath.isEmpty { dict["avatarPath"] = avatarPath }
    guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]) else { return }
    try? data.write(to: identityURL)
    AppState.shared.reloadPreviewIdentity()
    savedName = name
    savedAvatarPath = avatarPath
    showSavedConfirmation = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      showSavedConfirmation = false
    }
  }

  private func importAvatar(from url: URL) {
    guard let src = NSImage(contentsOf: url) else { return }
    let dest = containerDir.appending(path: "avatar.png")
    try? FileManager.default.createDirectory(at: containerDir, withIntermediateDirectories: true)
    try? FileManager.default.removeItem(at: dest)
    let size = NSSize(width: 72, height: 72)
    let resized = NSImage(size: size)
    resized.lockFocus()
    src.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1)
    resized.unlockFocus()
    guard let tiff = resized.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]),
          (try? png.write(to: dest)) != nil else { return }
    avatarPath = dest.path
    avatarImage = src
    save()
  }
}

#Preview {
  DraftsSettingsPane()
}
