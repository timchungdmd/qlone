import SwiftUI
import ARKit
import SceneKit

struct ARViewContainer: UIViewRepresentable {
    
    // CHANGED: Now accepts the full manager, matching ScanView's call site
    @ObservedObject var scanManager: ARScanManager
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        
        // 1. Inject the shared Session from the Manager
        // This ensures the camera feed matches the data being captured
        arView.session = scanManager.session
        
        // 2. Standard Configuration
        arView.automaticallyUpdatesLighting = true
        arView.autoenablesDefaultLighting = true
        
        // 3. Optional Debugging
        // Shows yellow feature points. Good for confirming tracking works.
        // arView.debugOptions = [.showFeaturePoints]
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Future proofing: If we add toggles for "Show Mesh" in the UI,
        // we can update uiView.debugOptions here based on scanManager state.
    }
}
