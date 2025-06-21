import SwiftUI
import ScreenCaptureKit


struct ContentView: View {
    @StateObject private var appSettings = AppSettings()
    @StateObject private var bleManager: GoveeBLEManager
    
    init() {
        let settings = AppSettings()
        _appSettings = StateObject(wrappedValue: settings)
        _bleManager = StateObject(wrappedValue: GoveeBLEManager(settings: settings))
    }
    
    var body: some View {
        TabView {
            ControlsView()
                .tabItem {
                    Label("Controls", systemImage: "slider.horizontal.3")
                }
            
            ScenesView()
                .tabItem {
                    Label("Scenes", systemImage: "sparkles")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .environmentObject(appSettings)
        .environmentObject(bleManager)
        .frame(minWidth: 480, idealWidth: 550, maxWidth: 650, minHeight: 500, idealHeight: 550, maxHeight: 650)
    }
}
