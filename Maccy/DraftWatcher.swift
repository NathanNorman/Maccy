import Foundation
import SwiftData

@MainActor
class DraftWatcher {
  private let draftsURL = URL.applicationSupportDirectory.appending(path: "Maccy/drafts.json")

  private var fileSource: DispatchSourceFileSystemObject?
  private var dirSource: DispatchSourceFileSystemObject?

  func start() {
    if FileManager.default.fileExists(atPath: draftsURL.path) {
      watchFile()
      ingest()
    } else {
      watchDirectory()
    }
  }

  private func watchFile() {
    fileSource?.cancel()
    fileSource = nil

    let fd = open(draftsURL.path, O_EVTONLY)
    guard fd >= 0 else {
      watchDirectory()
      return
    }

    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: fd,
      eventMask: [.write, .delete, .rename],
      queue: .main
    )
    source.setEventHandler { [weak self, weak source] in
      guard let self, let source else { return }
      let event = DispatchSource.FileSystemEvent(rawValue: source.data)
      if event.contains(.delete) || event.contains(.rename) {
        self.fileSource?.cancel()
        self.fileSource = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          self.watchFile()
          self.ingest()
        }
      } else {
        self.ingest()
      }
    }
    source.setCancelHandler { close(fd) }
    source.resume()
    fileSource = source
  }

  private func watchDirectory() {
    dirSource?.cancel()
    dirSource = nil

    let dirURL = draftsURL.deletingLastPathComponent()
    let fd = open(dirURL.path, O_EVTONLY)
    guard fd >= 0 else { return }

    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: fd,
      eventMask: .write,
      queue: .main
    )
    source.setEventHandler { [weak self] in
      guard let self else { return }
      if FileManager.default.fileExists(atPath: self.draftsURL.path) {
        self.dirSource?.cancel()
        self.dirSource = nil
        self.watchFile()
        self.ingest()
      }
    }
    source.setCancelHandler { close(fd) }
    source.resume()
    dirSource = source
  }

  func ingest() {
    guard let data = try? Data(contentsOf: draftsURL) else { return }

    struct Payload: Decodable {
      let id: String
      let label: String?
      let html: String
      let plain: String?
      let createdAt: String
    }

    guard let payloads = try? JSONDecoder().decode([Payload].self, from: data) else { return }

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
