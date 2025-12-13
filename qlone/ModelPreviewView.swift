import SwiftUI
import SceneKit
import MessageUI

@available(iOS 17.0, *)
struct ModelPreviewView: View {
    @ObservedObject var scanManager: ARScanManager
    @Binding var selectedTab: Int
    
    @State private var showMailComposer = false
    @State private var mailAttachmentURL: URL?
    @State private var mailSubject: String = "Dental Face Scan 3D Model"
    
    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let scene = scanManager.previewScene {
                    ModelPreviewSceneView(scene: scene)
                        .overlay(alignment: .topLeading) {
                            Text(scanManager.statusText)
                                .font(.caption)
                                .padding(8)
                                .background(.ultraThinMaterial,
                                            in: RoundedRectangle(cornerRadius: 10))
                                .padding()
                        }
                } else {
                    ZStack {
                        Color.black.opacity(0.9)
                        Text("No preview mesh yet.\nCapture and build preview first.")
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            controls
                .padding()
                .background(.ultraThinMaterial)
        }
        .navigationTitle("3D Model Preview")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMailComposer) {
            if let attachmentURL = mailAttachmentURL {
                MailComposerView(
                    subject: mailSubject,
                    body: "Attached is the 3D face scan exported from the app.",
                    recipients: [],
                    attachmentURL: attachmentURL,
                    mimeType: "application/octet-stream",
                    filename: attachmentURL.lastPathComponent
                )
            }
        }
    }
    
    // MARK: - Controls
    
    private var controls: some View {
        VStack(spacing: 12) {
            Text("Export / Manage Model")
                .font(.headline)
            
            // Export options – only when we have something to export
            if scanManager.previewScene != nil || scanManager.previewGeometry != nil {
                HStack {
                    Button("Email OBJ") {
                        exportAndEmail(format: .obj,
                                       subject: "Dental Face Scan – OBJ")
                    }
                    Button("Email PLY") {
                        exportAndEmail(format: .ply,
                                       subject: "Dental Face Scan – PLY")
                    }
                    Button("Email STL") {
                        exportAndEmail(format: .stl,
                                       subject: "Dental Face Scan – STL")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
            }
            
            // High-detail states
            if scanManager.isHighDetailReconstructing {
                ProgressView(scanManager.highDetailStatus)
                
                Button(role: .destructive) {
                    scanManager.cancelHighDetailAndDeleteImages()
                } label: {
                    Label("Cancel & delete captures", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
                
            } else if scanManager.highDetailModelURL == nil {
                Button {
                    scanManager.runHighDetailReconstruction()
                } label: {
                    Label("Run High-Detail Photogrammetry",
                          systemImage: "cube.transparent")
                }
                .buttonStyle(.bordered)
                
            } else {
                // Photogrammetry finished: single cleanup + return flow
                Button(role: .destructive) {
                    scanManager.deleteHighDetailAndCaptures()
                    selectedTab = 0
                } label: {
                    Label("Delete mesh & return to main menu",
                          systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
            }
            
            // Plain “back” (no confirmation once not reconstructing)
            Button {
                selectedTab = 0
            } label: {
                Label("Return to Main Menu",
                      systemImage: "arrowshape.turn.up.backward")
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
    }
    
    // MARK: - Export helper
    
    private func exportAndEmail(format: MeshExportFormat, subject: String) {
        if let url = scanManager.exportPreviewMesh(format: format) {
            mailSubject = subject
            mailAttachmentURL = url
            showMailComposer = true
        }
    }
}

// MARK: - SceneKit view

@available(iOS 17.0, *)
struct ModelPreviewSceneView: UIViewRepresentable {
    var scene: SCNScene?
    
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = true   // free orbit / pan / zoom
        view.backgroundColor = .black
        view.antialiasingMode = .multisampling4X
        return view
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.scene = scene
    }
}

// MARK: - Mail composer

@available(iOS 17.0, *)
struct MailComposerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    
    var subject: String
    var body: String
    var recipients: [String]
    var attachmentURL: URL
    var mimeType: String
    var filename: String
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposerView
        init(parent: MailComposerView) { self.parent = parent }
        
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            controller.dismiss(animated: true) {
                self.parent.dismiss()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        guard MFMailComposeViewController.canSendMail() else {
            return UIViewController()
        }
        
        let mail = MFMailComposeViewController()
        mail.mailComposeDelegate = context.coordinator
        mail.setSubject(subject)
        mail.setMessageBody(body, isHTML: false)
        mail.setToRecipients(recipients)
        
        if let data = try? Data(contentsOf: attachmentURL) {
            mail.addAttachmentData(data, mimeType: mimeType, fileName: filename)
        }
        
        return mail
    }
    
    func updateUIViewController(_ uiViewController: UIViewController,
                                context: Context) { }
}
