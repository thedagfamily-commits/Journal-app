import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            EntryListView()
                .tabItem {
                    Label("Journal", systemImage: "book")
                }

            RecordEntryView()
                .tabItem {
                    Label("Record", systemImage: "mic")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(EntryStore())
}
