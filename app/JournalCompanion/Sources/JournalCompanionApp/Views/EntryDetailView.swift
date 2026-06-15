import SwiftUI

struct EntryDetailView: View {
    let entryID: UUID

    @EnvironmentObject private var entryStore: EntryStore
    @State private var entry: Entry?
    @State private var loadError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let entry {
                    Text(entry.createdAt.formatted(date: .long, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if entry.crisisFlag {
                        Text(CrisisResponse.fixedMessage)
                            .font(.body)
                    } else {
                        if let summary = entry.summary, !summary.isEmpty {
                            Text(summary)
                                .font(.headline)
                        }

                        if !entry.moodTags.isEmpty {
                            tagSection(title: "Mood", items: entry.moodTags)
                        }
                        if !entry.mentionedPeople.isEmpty {
                            tagSection(title: "People", items: entry.mentionedPeople)
                        }
                        if !entry.mentionedPlaces.isEmpty {
                            tagSection(title: "Places", items: entry.mentionedPlaces)
                        }
                        if !entry.statedIntentions.isEmpty {
                            tagSection(title: "Intentions", items: entry.statedIntentions)
                        }
                    }

                    Divider()

                    Text(entry.rawContent)
                        .font(.body)
                } else if let loadError {
                    Text(loadError)
                        .foregroundStyle(.red)
                } else {
                    ProgressView()
                }
            }
            .padding()
        }
        .navigationTitle("Entry")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            load()
        }
    }

    private func tagSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private func load() {
        do {
            entry = try entryStore.loadEntry(id: entryID)
        } catch {
            loadError = "Couldn't load this entry: \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        EntryDetailView(entryID: UUID())
            .environmentObject(EntryStore())
    }
}
