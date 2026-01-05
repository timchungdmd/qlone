// FILE: qlone/ARScanManager+Preview.swift
import Foundation
import ARKit
import SceneKit

extension ARScanManager {

    /// Updates the point cloud visualization based on the current ARFrame
    func updatePointCloud(from frame: ARFrame) {
        // 1. Get Face Anchor
        guard let faceAnchor = frame.anchors.first(where: { $0 is ARFaceAnchor }) as? ARFaceAnchor else { return }
        
        // 2. Extract Vertices
        let vertices = faceAnchor.geometry.vertices
        
        // 3. Store for the current state (UI Visualization)
        // We throttle this to avoid UI lag (e.g., update every 10 frames or so)
        if frameCountForState % 10 == 0 {
            self.facePointsByState[captureState] = vertices
            
            // If you want raw points (world space), apply transform:
            let transform = faceAnchor.transform
            let worldPoints = vertices.map { vertex -> SIMD3<Float> in
                let vector = SIMD4<Float>(vertex.x, vertex.y, vertex.z, 1)
                let world = transform * vector
                return SIMD3<Float>(world.x, world.y, world.z)
            }
            self.rawPointsByState[captureState] = worldPoints
        }
        
        // 4. Capture Texture Preview (Snapshot)
        if frameCountForState % 30 == 0 {
            let buffer = frame.capturedImage
            if let image = createUIImage(from: buffer) {
                self.lastTextureImage = image
            }
        }
    }
    
    // Helper to convert CVPixelBuffer to UIImage for preview
    private func createUIImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
    }
}
