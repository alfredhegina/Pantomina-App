import SwiftUI
import SwiftData
import UIKit

struct RootView: View {
    @Query private var metaRows: [AppMeta]
    @Environment(\.modelContext) private var modelContext

    private var onboarded: Bool {
        metaRows.first(where: { $0.key == "main" })?.onboardingComplete == true
    }

    var body: some View {
        Group {
            if onboarded {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .background(Color.pantomina.ground)
        .onAppear {
            _ = Bootstrap.ensureMeta(modelContext)
            Self.applyPaperChrome()
        }
    }

    /// Warm paper across nav / lists: Spec ground `#FAF8F5`, not system grey.
    private static func applyPaperChrome() {
        let ground = UIColor(Color.pantomina.ground)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = ground
        appearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance

        UITableView.appearance().backgroundColor = ground
        UICollectionView.appearance().backgroundColor = ground
    }
}

struct MainTabView: View {
    @State private var tab = 0
    @State private var previousTab = 0
    @State private var showAddSheet = false

    var body: some View {
        TabView(selection: $tab) {
            HomeView(onAdd: { showAddSheet = true }, onOpenBills: { tab = 3 })
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)
            ReceiptsView()
                .tabItem { Label("Receipts", systemImage: "doc.text") }
                .tag(1)
            Color.clear
                .tabItem { Label("Add", systemImage: "plus.circle.fill") }
                .tag(2)
            BillsView()
                .tabItem { Label("Bills", systemImage: "creditcard") }
                .tag(3)
            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis") }
                .tag(4)
        }
        .tint(Color.pantomina.quietAccent)
        .toolbarBackground(Color.pantomina.ground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onChange(of: tab) { oldValue, newValue in
            if newValue == 2 {
                previousTab = oldValue == 2 ? previousTab : oldValue
                showAddSheet = true
                tab = previousTab
            } else {
                previousTab = newValue
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddEntryView(presentsAsSheet: true)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.pantomina.ground)
        }
    }
}
