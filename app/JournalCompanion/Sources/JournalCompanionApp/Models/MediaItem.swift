import Foundation

/// Mirrors PRD v3 §4. Not used by the Phase 1 capture loop yet — included now
/// so the schema is in place before Phase 3 (proactive prompting / media scan)
/// builds on top of it.
enum MediaType: String, Codable, CaseIterable {
    case image
    case video
}

struct MediaItem: Identifiable, Codable, Equatable {
    let id: UUID
    var filePath: String
    var type: MediaType
    var capturedAt: Date

    /// AI-generated description (Phase 3: Vision framework + Foundation Models multimodal prompt).
    var caption: String?

    /// Keywords from the vision model.
    var tags: [String]

    init(
        id: UUID = UUID(),
        filePath: String,
        type: MediaType,
        capturedAt: Date,
        caption: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.filePath = filePath
        self.type = type
        self.capturedAt = capturedAt
        self.caption = caption
        self.tags = tags
    }
}
