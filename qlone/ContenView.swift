import SwiftUI

struct ContentView: View {
    // Single source of truth for the app state
    @StateObject private var scanManager = ARScanManager()
    
    // Tab selection state
    @State private var selectedTab: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            // TAB 1: Scanning
            ScanView(scanManager: scanManager) // <--- FIXED: Removed 'selectedTab'
                .tabItem {
                    Label("Scan", systemImage: "camera.viewfinder")
                }
                .tag(0)
            
            // TAB 2: Gallery / Preview
            // (Assuming you have a gallery view, otherwise we reuse ModelPreview)
            ModelPreviewView(scanManager: scanManager)
                .tabItem {
                    Label("Preview", systemImage: "cube.transparent")
                }
                .tag(1)
        }
        .accentColor(.green)
        // Keep the screen awake during scanning
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }
}
