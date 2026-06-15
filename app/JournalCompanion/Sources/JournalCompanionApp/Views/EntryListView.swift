import SwiftUI

struct EntryListView: View {
    @EnvironmentObject private var entryStore: EntryStore

    var body: some View {
        NavigationStack {
            List {
                if entryStore.manifest.isEmpty {
                    ContentUnavailableView(
                        "No entries yet",
                        systemImage: "book",
                        description: Text("Record your first journal entry from the Record tab.")
                    )
                } else {
                    ForEach(entryStore.manifest) { record in
                        NavigationLink(value: record.id) {
                            EntryRow(record: record)
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
            .navigationTitle("Journal")
            .navigationDestination(for: UUID.self) { id in
                EntryDetailView(entryID: id)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let record = entryStore.manifest[index]
            try? entryStore.delete(id: record.id)
        }
    }
}

private struct EntryRow: View {
    let record: EntryManifestRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)

            if record.crisisFlag {
                Text("Entry saved")
                    .font(.body)
            } else if let summary = record.summarySnippet, !summary.isEmpty {
                Text(summary)
                    .font(.body)
                    .lineLimit(2)
            } else {
                Text("(no summary)")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            if !record.moodTags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(record.moodTags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    EntryListView()
        .environmentObject(EntryStore())
}
