import SwiftUI
import SceneKit

struct ModelPreviewView: View {
    @ObservedObject var scanManager: ARScanManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack(spacing: 20) {
            
            // 1. 3D PREVIEW AREA
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Show 3D Model if available
                if let scene = scanManager.previewScene, scanManager.highDetailModelURL != nil {
                    PreviewSceneWrapper(scene: scene)
                } else {
                    // Placeholder state
                    VStack(spacing: 15) {
                        Image(systemName: "camera.metering.center.weighted")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("Ready to Process")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text("\(scanManager.frameCountForState) images captured")
                            .foregroundColor(.gray)
                    }
                }
                
                // Loading Overlay
                if scanManager.isHighDetailReconstructing {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .colorInvert()
                        Text(scanManager.highDetailStatus)
                            .foregroundColor(.white)
                            .padding(.top)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
            }
            .frame(maxHeight: .infinity)
            
            // 2. ACTION PANEL
            VStack(spacing: 15) {
                
                HStack(spacing: 20) {
                    // EXPORT RAW (To Mac)
                    Button(action: {
                        Task {
                            isExporting = true
                            if let url = await scanManager.prepareRawDataForExport() {
                                self.exportURL = url
                                self.showShareSheet = true
                            }
                            isExporting = false
                        }
                    }) {
                        VStack {
                            Image(systemName: "folder.fill")
                                .font(.title)
                            Text("Send Raw")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    // RECONSTRUCT (On iPhone)
                    Button(action: {
                        if scanManager.frameCountForState > 10 {
                            scanManager.runHighDetailReconstruction()
                        }
                    }) {
                        VStack {
                            Image(systemName: "bolt.fill")
                                .font(.title)
                            Text("Create 3D")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(scanManager.frameCountForState > 10 ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(scanManager.isHighDetailReconstructing || scanManager.frameCountForState <= 10)
                }
                
                // EXPORT FINAL USDZ
                if scanManager.highDetailModelURL != nil {
                    Button("Export Final USDZ") {
                        self.exportURL = scanManager.highDetailModelURL
                        self.showShareSheet = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
        }
        // MARK: - Navigation Bar Items
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        // MARK: - Alerts & Sheets
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Delete & Re-scan?"),
                message: Text("This will permanently delete the current model and all images."),
                primaryButton: .destructive(Text("Delete All")) {
                    // 1. Wipe Data
                    scanManager.restart()
                    // 2. Go back to Scan View
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel()
            )
        }
    }
}

// MARK: - Helpers

struct PreviewSceneWrapper: UIViewRepresentable {
    let scene: SCNScene
    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.allowsCameraControl = true
        v.autoenablesDefaultLighting = true
        v.backgroundColor = .clear
        return v
    }
    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.scene = scene
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
