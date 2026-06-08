import Foundation
import SwiftData

@Model
class DraftItem {
  var id: String
  var label: String?
  var html: String
  var plain: String?
  var createdAt: Date

  init(id: String, label: String?, html: String, plain: String?, createdAt: Date) {
    self.id = id
    self.label = label
    self.html = html
    self.plain = plain
    self.createdAt = createdAt
  }
}
