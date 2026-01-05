import SwiftUI

@main
struct DentalFaceScanApp: App {
    var body: some Scene {
        WindowGroup {
            // FIX: No arguments needed here anymore.
            // ContentView creates its own ARScanManager.
            ContentView()
        }
    }
}
