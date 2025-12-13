import SwiftUI

@main
struct DentalFaceScanApp: App {
    @StateObject private var scanManager = ARScanManager()

    var body: some Scene {
        WindowGroup {
            if #available(iOS 17.0, *) {
                ContentView(scanManager: scanManager)
            } else {
                Text("Requires iOS 17 or later")
            }
        }
    }
}
