import Foundation

enum EntryMarkdownCoderError: Error {
    case missingFrontmatter
    case invalidFrontmatter(String)
    case missingField(String)
}

/// Converts `Entry` to/from a markdown file with a YAML-style frontmatter
/// block, per PRD §3 ("portable, human-readable formats").
///
/// This intentionally implements a *constrained subset* of YAML — scalars and
/// single-line flow lists (`[a, b, c]`) — rather than depending on a full YAML
/// library. That's enough for what this app writes, and the files remain
/// readable/editable by hand or by other tools. If you ever hand-edit one of
/// these files, stick to that subset (one `key: value` per line, lists as
/// `[item, item]` with double-quoted items if they contain commas/brackets).
enum EntryMarkdownCoder {

    static func encode(_ entry: Entry) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var lines: [String] = []
        lines.append("---")
        lines.append("id: \(entry.id.uuidString)")
        lines.append("created_at: \(formatter.string(from: entry.createdAt))")
        lines.append("type: \(entry.type.rawValue)")
        lines.append("crisis_flag: \(entry.crisisFlag)")
        lines.append("mood_tags: \(encodeList(entry.moodTags))")
        lines.append("media_references: \(encodeList(entry.mediaReferences))")
        lines.append("mentioned_people: \(encodeList(entry.mentionedPeople))")
        lines.append("mentioned_places: \(encodeList(entry.mentionedPlaces))")
        lines.append("stated_intentions: \(encodeList(entry.statedIntentions))")
        lines.append("---")
        lines.append("")

        if entry.crisisFlag {
            // No AI summary for crisis-flagged entries (PRD §5/§6) — the app
            // shows CrisisResponse.fixedMessage instead, computed at read time.
            lines.append("## Entry")
            lines.append("")
            lines.append(entry.rawContent)
        } else {
            if let summary = entry.summary, !summary.isEmpty {
                lines.append("## Summary")
                lines.append("")
                lines.append(summary)
                lines.append("")
            }
            lines.append("## Entry")
            lines.append("")
            lines.append(entry.rawContent)
        }
        lines.append("")

        return lines.joined(separator: "\n")
    }

    static func decode(_ markdown: String) throws -> Entry {
        let lines = markdown.components(separatedBy: "\n")
        guard lines.first == "---" else {
            throw EntryMarkdownCoderError.missingFrontmatter
        }

        guard let closingIndex = lines.dropFirst().firstIndex(of: "---") else {
            throw EntryMarkdownCoderError.missingFrontmatter
        }

        let frontmatterLines = lines[1..<closingIndex]
        var fields: [String: String] = [:]
        for rawLine in frontmatterLines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, let colonIndex = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
            fields[key] = value
        }

        guard let idString = fields["id"], let id = UUID(uuidString: idString) else {
            throw EntryMarkdownCoderError.missingField("id")
        }
        guard let createdAtString = fields["created_at"] else {
            throw EntryMarkdownCoderError.missingField("created_at")
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var createdAt = formatter.date(from: createdAtString)
        if createdAt == nil {
            // Fall back to without-fractional-seconds in case of hand edits.
            formatter.formatOptions = [.withInternetDateTime]
            createdAt = formatter.date(from: createdAtString)
        }
        guard let createdAt else {
            throw EntryMarkdownCoderError.invalidFrontmatter("created_at: \(createdAtString)")
        }

        guard let typeString = fields["type"], let type = EntryType(rawValue: typeString) else {
            throw EntryMarkdownCoderError.missingField("type")
        }

        let crisisFlag = (fields["crisis_flag"] ?? "false") == "true"
        let moodTags = decodeList(fields["mood_tags"])
        let mediaReferences = decodeList(fields["media_references"])
        let mentionedPeople = decodeList(fields["mentioned_people"])
        let mentionedPlaces = decodeList(fields["mentioned_places"])
        let statedIntentions = decodeList(fields["stated_intentions"])

        // Body: everything after the closing "---" line.
        let bodyLines = Array(lines[(closingIndex + 1)...])
        let body = bodyLines.joined(separator: "\n")

        let summary = extractSection(named: "Summary", from: body)
        let rawContent = extractSection(named: "Entry", from: body) ?? body.trimmingCharacters(in: .whitespacesAndNewlines)

        return Entry(
            id: id,
            createdAt: createdAt,
            type: type,
            rawContent: rawContent,
            summary: crisisFlag ? nil : summary,
            moodTags: moodTags,
            mediaReferences: mediaReferences,
            mentionedPeople: mentionedPeople,
            mentionedPlaces: mentionedPlaces,
            statedIntentions: statedIntentions,
            crisisFlag: crisisFlag
        )
    }

    // MARK: - List encoding (flow-style YAML subset)

    private static func encodeList(_ items: [String]) -> String {
        if items.isEmpty { return "[]" }
        let encoded = items.map { item -> String in
            if item.contains(",") || item.contains("[") || item.contains("]") || item.contains("\"") {
                let escaped = item.replacingOccurrences(of: "\"", with: "\\\"")
                return "\"\(escaped)\""
            }
            return item
        }
        return "[" + encoded.joined(separator: ", ") + "]"
    }

    private static func decodeList(_ raw: String?) -> [String] {
        guard var value = raw?.trimmingCharacters(in: .whitespaces) else { return [] }
        guard value.hasPrefix("[") && value.hasSuffix("]") else { return [] }
        value = String(value.dropFirst().dropLast())
        if value.trimmingCharacters(in: .whitespaces).isEmpty { return [] }

        var items: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = value.makeIterator()
        while let char = iterator.next() {
            switch char {
            case "\"":
                inQuotes.toggle()
            case ",":
                if inQuotes {
                    current.append(char)
                } else {
                    items.append(current.trimmingCharacters(in: .whitespaces))
                    current = ""
                }
            default:
                current.append(char)
            }
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            items.append(current.trimmingCharacters(in: .whitespaces))
        }
        return items.map { $0.replacingOccurrences(of: "\\\"", with: "\"") }
    }

    // MARK: - Section extraction

    /// Extracts the body text under a `## <name>` heading, up to the next
    /// `##` heading or end of string.
    private static func extractSection(named name: String, from body: String) -> String? {
        let lines = body.components(separatedBy: "\n")
        guard let startIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "## \(name)" }) else {
            return nil
        }
        var sectionLines: [String] = []
        for line in lines[(startIndex + 1)...] {
            if line.hasPrefix("## ") { break }
            sectionLines.append(line)
        }
        let text = sectionLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
