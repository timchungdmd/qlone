import SwiftUI

@available(iOS 17.0, *)
struct ContentView: View {
    @ObservedObject var scanManager: ARScanManager
    @State private var selectedTab: Int = 0   // ContentView owns the tab state

    var body: some View {
        TabView(selection: $selectedTab) {
            // TAB 0 – Live scan
            ScanView(scanManager: scanManager)
                .tabItem {
                    Label("Scan", systemImage: "camera.viewfinder")
                }
                .tag(0)

            // TAB 1 – 3D preview / export
            ModelPreviewView(
                scanManager: scanManager,
                selectedTab: $selectedTab      // pass binding down
            )
            .tabItem {
                Label("Preview", systemImage: "cube.transparent")
            }
            .tag(1)
        }
    }
}
