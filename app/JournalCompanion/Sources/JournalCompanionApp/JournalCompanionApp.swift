import SwiftUI

@main
struct JournalCompanionApp: App {
    @StateObject private var entryStore = EntryStore()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(entryStore)

                if showSplash {
                    SplashView {
                        withAnimation(.easeOut(duration: 0.5)) {
                            showSplash = false
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }
}
