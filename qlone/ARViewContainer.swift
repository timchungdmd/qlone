// ARViewContainer.swift
import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
    let session: ARSession

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // We will configure the session ourselves via ARScanManager.start()
        arView.automaticallyConfigureSession = false

        // Attach the shared ARSession from ARScanManager
        arView.session = session

        // Optional visual tweaks
        arView.renderOptions.insert(.disableMotionBlur)
        arView.renderOptions.insert(.disableDepthOfField)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Make sure the ARView keeps using the same shared session
        if uiView.session !== session {
            uiView.session = session
        }
    }
}
