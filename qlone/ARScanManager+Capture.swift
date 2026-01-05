import ARKit
import SceneKit
import Foundation
import UIKit

extension ARScanManager {
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isRunning else { return }
        
        // 1. Determine "Should Save" based on Active Camera
        let shouldSave: Bool
        
        if captureMode == .manual {
            shouldSave = pendingManualCapture
        } else {
            // AUTO MODE LOGIC
            let now = Date().timeIntervalSince1970
            let timeElapsed = (now - lastCaptureTimestamp) > 0.6 // 0.6s interval
            
            if useFrontCamera {
                // --- SELFIE LOGIC (Requires Face) ---
                let isFaceVisible = frame.anchors.contains(where: { $0 is ARFaceAnchor })
                shouldSave = timeElapsed && isFaceVisible
                
                if !isFaceVisible { statusText = "Find Face..." }
                
            } else {
                // --- REAR LOGIC (Always Capture if time elapsed) ---
                shouldSave = timeElapsed
            }
        }
        
        // 2. Save
        if shouldSave {
            // Convert to UIImage (Handles orientation)
            if let imageToSave = self.createUIImage(from: frame) {
                
                Task {
                    await imageWriter.write(image: imageToSave, state: captureState)
                }
                
                frameCountForState += 1
                lastCaptureTimestamp = Date().timeIntervalSince1970
                
                statusText = pendingManualCapture ? "Captured!" : "Scanning (\(frameCountForState))"
                if pendingManualCapture { pendingManualCapture = false }
            }
        }
    }
    
    func manualCapture() {
        pendingManualCapture = true
    }
    
    // Helper: Correct Orientation
    private func createUIImage(from frame: ARFrame) -> UIImage? {
        let pixelBuffer = frame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        
        // Use .right for both (Standard Portrait behavior for ARKit buffers)
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
    }
}
