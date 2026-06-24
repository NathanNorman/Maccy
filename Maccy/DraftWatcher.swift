import Foundation
import SwiftData

@MainActor
class DraftWatcher {
  static let draftsDir = URL.applicationSupportDirectory.appending(path: "Maccy/drafts")
  private static let legacyURL = URL.applicationSupportDirectory.appending(path: "Maccy/drafts.json")

  private var dirSource: DispatchSourceFileSystemObject?

  func start() {
    try? FileManager.default.removeItem(at: Self.legacyURL)
    try? FileManager.default.createDirectory(at: Self.draftsDir, withIntermediateDirectories: true)
    watchDirectory()
    ingest()
  }

  private func watchDirectory() {
    dirSource?.cancel()
    dirSource = nil

    let fd = open(Self.draftsDir.path, O_EVTONLY)
    guard fd >= 0 else { return }

    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: fd,
      eventMask: .write,
      queue: .main
    )
    source.setEventHandler { [weak self] in
      self?.ingest()
    }
    source.setCancelHandler { close(fd) }
    source.resume()
    dirSource = source
  }

  func ingest() {
    let fm = FileManager.default
    guard let files = try? fm.contentsOfDirectory(
      at: Self.draftsDir,
      includingPropertiesForKeys: nil
    ) else { return }

    struct Payload: Decodable {
      let id: String
      let label: String?
      let html: String
      let plain: String?
      let createdAt: String
    }

    var payloads: [Payload] = []
    for file in files where file.pathExtension == "json" {
      if let data = try? Data(contentsOf: file),
         let payload = try? JSONDecoder().decode(Payload.self, from: data) {
        payloads.append(payload)
      }
    }

    let context = Storage.shared.context
    let existing = (try? context.fetch(FetchDescriptor<DraftItem>())) ?? []
    let newIds = Set(payloads.map(\.id))

    for item in existing where !newIds.contains(item.id) {
      context.delete(item)
    }

    let formatter = ISO8601DateFormatter()
    for payload in payloads {
      if let existing = existing.first(where: { $0.id == payload.id }) {
        existing.label = payload.label
        existing.html = payload.html
        existing.plain = payload.plain
      } else {
        let date = formatter.date(from: payload.createdAt) ?? Date.now
        context.insert(DraftItem(
          id: payload.id,
          label: payload.label,
          html: payload.html,
          plain: payload.plain,
          createdAt: date
        ))
      }
    }

    try? context.save()

    let updated = (try? context.fetch(
      FetchDescriptor<DraftItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
    )) ?? []
    let newDecorators = updated.map { DraftItemDecorator($0) }
    let previousDraftId = AppState.shared.selectedDraft?.draftId
    AppState.shared.drafts = newDecorators
    AppState.shared.selectedDraft = newDecorators.first { $0.draftId == previousDraftId }
      ?? newDecorators.first
  }
}
