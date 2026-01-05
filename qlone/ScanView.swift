import SwiftUI
import ARKit
import SceneKit

struct ScanView: View {
    @ObservedObject var scanManager: ARScanManager
    
    var body: some View {
        ZStack {
            // 1. Camera Feed
            ScanARViewWrapper(session: scanManager.session)
                .edgesIgnoringSafeArea(.all)
            
            // 2. UI Controls
            VStack {
                // --- TOP BAR ---
                HStack {
                    // FLIP CAMERA BUTTON
                    Button(action: {
                        scanManager.toggleCamera()
                    }) {
                        Image(systemName: "camera.rotate.fill")
                            .font(.title2)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text(scanManager.statusText)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Mode Picker
                    Picker("Mode", selection: $scanManager.captureState) {
                        Text("Smile").tag(CaptureState.smile)
                        Text("Repose").tag(CaptureState.repose)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
                .padding(.top, 50)
                .padding(.horizontal)
                
                Spacer()
                
                // --- BOTTOM CONTROLS ---
                HStack(spacing: 30) {
                    // RESET
                    Button(action: { scanManager.restart() }) {
                        Image(systemName: "trash")
                            .font(.title)
                            .padding()
                            .background(.red.opacity(0.8))
                            .clipShape(Circle())
                            .foregroundColor(.white)
                    }
                    
                    // CAPTURE (Start/Stop)
                    Button(action: {
                        if scanManager.isRunning {
                            scanManager.stop()
                        } else {
                            scanManager.start()
                        }
                    }) {
                        Image(systemName: scanManager.isRunning ? "stop.circle.fill" : "circle.inset.filled")
                            .font(.system(size: 70))
                            .foregroundColor(scanManager.isRunning ? .red : .white)
                    }
                    
                    // PREVIEW / PROCESS
                    NavigationLink(destination: ModelPreviewView(scanManager: scanManager)) {
                        VStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title)
                        }
                        .padding()
                        .background(.blue.opacity(0.8))
                        .clipShape(Circle())
                        .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// Helper
private struct ScanARViewWrapper: UIViewRepresentable {
    let session: ARSession
    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView()
        view.session = session
        view.automaticallyUpdatesLighting = true
        return view
    }
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}
