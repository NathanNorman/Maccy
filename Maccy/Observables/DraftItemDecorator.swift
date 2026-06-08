import Foundation

@Observable
class DraftItemDecorator: Identifiable {
  let id: UUID = UUID()
  let draftId: String
  let html: String
  let plain: String?
  let createdAt: Date

  var displayTitle: String {
    if let label = label, !label.isEmpty { return label }
    if let plain = plain, !plain.isEmpty { return String(plain.prefix(60)) }
    return "(untitled)"
  }

  private let label: String?

  init(_ item: DraftItem) {
    draftId = item.id
    label = item.label
    html = item.html
    plain = item.plain
    createdAt = item.createdAt
  }
}
