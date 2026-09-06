import SwiftUI

struct RootView: View {
    @Environment(Store.self) private var store

    var body: some View {
        TabView {
            DeckListView()
                .tabItem { Label("المجموعات", systemImage: "rectangle.stack") }
            TodayView()
                .tabItem { Label("المراجعة", systemImage: "brain.head.profile") }
                .badge(store.totalDue)
            StatsView()
                .tabItem { Label("الإحصاءات", systemImage: "chart.bar.xaxis") }
        }
        .onAppear { store.addSampleDeckIfEmpty() }
    }
}
