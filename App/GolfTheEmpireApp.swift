import SwiftUI

@main
struct GolfTheEmpireApp: App {
    @State private var store = GameStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
        .onChange(of: scenePhase) {
            if scenePhase != .active { store.save() }
        }
    }
}

struct RootView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        switch store.screen {
        case .start: StartView()
        case .pickPlot: PlotPickerView()
        case .course: CourseScreen()
        case .gallery: AssetGalleryView()
        }
    }
}
