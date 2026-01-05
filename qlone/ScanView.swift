import SwiftUI
import ARKit
import SceneKit

struct ScanView: View {
    @ObservedObject var scanManager: ARScanManager
    
    // Alert state for overwriting data
    @State private var showDeleteConfirmation = false
    // NEW: Alert state for the Reset/Trash button
    @State private var showResetConfirmation = false
    
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
                    // RESET (Trash Can)
                    Button(action: {
                        // Ask for confirmation before deleting everything
                        showResetConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .font(.title)
                            .padding()
                            .background(.red.opacity(0.8))
                            .clipShape(Circle())
                            .foregroundColor(.white)
                    }
                    
                    // CAPTURE (Start/Stop) with Confirmation Logic
                    Button(action: {
                        if scanManager.isRunning {
                            // If running, simply stop
                            scanManager.stop()
                        } else {
                            // If stopped, check if we have existing data
                            if scanManager.frameCountForState > 0 {
                                // Ask for confirmation before overwriting
                                showDeleteConfirmation = true
                            } else {
                                // No data, start immediately
                                scanManager.start()
                            }
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
        // Stop scanning when navigating away
        .onDisappear {
            scanManager.stop()
        }
        // ALERT 1: Start New Scan (Overwrite)
        .alert("Start New Scan?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete & Start", role: .destructive) {
                scanManager.restart()
            }
        } message: {
            Text("This will delete your previous scan data and start a new session.")
        }
        // ALERT 2: Reset Data (Trash Button)
        .alert("Delete Scan Data?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                // Clears data but DOES NOT start scanning
                scanManager.resetAndIdle()
            }
        } message: {
            Text("Are you sure? This will permanently delete all photos and mesh data.")
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
