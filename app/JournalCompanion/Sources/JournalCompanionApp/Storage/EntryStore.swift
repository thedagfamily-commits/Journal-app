import Foundation

enum EntryStoreError: Error {
    case entryNotFound(UUID)
}

/// Manages the on-disk journal: one markdown file per entry under `entries/`,
/// plus a `manifest.json` index for fast listing without re-parsing every file.
///
/// Storage root defaults to `<Documents>/JournalData` — see PRD §3 (local-first,
/// portable, human-readable storage; no backend; no developer access).
///
/// `manifest.json` is a *derived* index — `entries/*.md` is the source of
/// truth. If the manifest and an entry file ever disagree (e.g. a file was
/// hand-edited), `rebuildManifest()` can regenerate it from the markdown files.
@MainActor
final class EntryStore: ObservableObject {
    @Published private(set) var manifest: [EntryManifestRecord] = []

    let rootURL: URL

    private var entriesURL: URL { rootURL.appendingPathComponent("entries", isDirectory: true) }
    private var manifestURL: URL { rootURL.appendingPathComponent("manifest.json") }

    init(rootURL: URL? = nil) {
        if let rootURL {
            self.rootURL = rootURL
        } else {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.rootURL = documents.appendingPathComponent("JournalData", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: entriesURL, withIntermediateDirectories: true)
        loadManifest()
    }

    // MARK: - Manifest

    func loadManifest() {
        guard let data = try? Data(contentsOf: manifestURL) else {
            manifest = []
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        manifest = (try? decoder.decode([EntryManifestRecord].self, from: data)) ?? []
    }

    private func saveManifest() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let sorted = manifest.sorted { $0.createdAt > $1.createdAt }
        let data = try encoder.encode(sorted)
        try data.write(to: manifestURL, options: .atomic)
        manifest = sorted
    }

    /// Regenerates `manifest.json` from the markdown files on disk. Useful if
    /// entries were edited/added outside the app (e.g. via cloud sync).
    func rebuildManifest() throws {
        let fileURLs = try FileManager.default.contentsOfDirectory(at: entriesURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "md" }

        var records: [EntryManifestRecord] = []
        for fileURL in fileURLs {
            let markdown = try String(contentsOf: fileURL, encoding: .utf8)
            let entry = try EntryMarkdownCoder.decode(markdown)
            records.append(EntryManifestRecord(entry: entry))
        }
        manifest = records
        try saveManifest()
    }

    // MARK: - CRUD

    func save(_ entry: Entry) throws {
        let markdown = EntryMarkdownCoder.encode(entry)
        let fileURL = entriesURL.appendingPathComponent("\(entry.id.uuidString).md")
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)

        manifest.removeAll { $0.id == entry.id }
        manifest.append(EntryManifestRecord(entry: entry))
        try saveManifest()
    }

    func loadEntry(id: UUID) throws -> Entry {
        let fileURL = entriesURL.appendingPathComponent("\(id.uuidString).md")
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw EntryStoreError.entryNotFound(id)
        }
        let markdown = try String(contentsOf: fileURL, encoding: .utf8)
        return try EntryMarkdownCoder.decode(markdown)
    }

    func delete(id: UUID) throws {
        let fileURL = entriesURL.appendingPathComponent("\(id.uuidString).md")
        try? FileManager.default.removeItem(at: fileURL)
        manifest.removeAll { $0.id == id }
        try saveManifest()
    }

    /// One-tap "delete all data" (PRD §6). Note: this only deletes the local
    /// copy — see PRD §10 open question re: cloud-synced copies, not yet
    /// addressed (Phase 4).
    func deleteAll() throws {
        try? FileManager.default.removeItem(at: rootURL)
        try FileManager.default.createDirectory(at: entriesURL, withIntermediateDirectories: true)
        manifest = []
        try saveManifest()
    }
}
