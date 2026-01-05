import ARKit
import SceneKit
import Foundation
import UIKit
import AVFoundation
import CoreVideo

extension ARScanManager {
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isRunning else { return }
        
        // 1. Check Capture Conditions
        let shouldSave: Bool
        if captureMode == .manual {
            shouldSave = pendingManualCapture
        } else {
            let now = Date().timeIntervalSince1970
            let timeElapsed = (now - lastCaptureTimestamp) > 0.6
            
            if useFrontCamera {
                let isFaceVisible = frame.anchors.contains(where: { $0 is ARFaceAnchor })
                shouldSave = timeElapsed && isFaceVisible
                if !isFaceVisible { statusText = "Find Face..." }
            } else {
                shouldSave = timeElapsed
            }
        }
        
        // 2. Capture
        if shouldSave {
            let colorBuffer = frame.capturedImage
            
            // EXTRACT METADATA (Critical for Gravity)
            let metadata = CMCopyDictionaryOfAttachments(
                allocator: kCFAllocatorDefault,
                target: colorBuffer,
                attachmentMode: kCMAttachmentMode_ShouldPropagate
            ) as? [String: Any]
            
            // PREPARE DEPTH (Unified)
            var rawDepth: CVPixelBuffer? = nil
            
            if useFrontCamera {
                // Front: Convert Disparity -> Depth
                if let depthData = frame.capturedDepthData {
                    let converted = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
                    rawDepth = converted.depthDataMap
                }
            } else {
                // Rear: LiDAR SceneDepth
                rawDepth = frame.sceneDepth?.depthMap
            }
            
            // Save to Disk (Color + Depth)
            Task {
                await imageWriter.write(
                    colorBuffer: colorBuffer,
                    metadata: metadata,
                    rawDepthBuffer: rawDepth,
                    state: captureState
                )
            }
            
            // UI Feedback
            frameCountForState += 1
            lastCaptureTimestamp = Date().timeIntervalSince1970
            statusText = pendingManualCapture ? "Captured!" : "Scanning (\(frameCountForState))"
            
            if frameCountForState % 5 == 0 {
                self.updatePreviewThumbnail(from: colorBuffer)
            }
            
            if pendingManualCapture { pendingManualCapture = false }
        }
    }
    
    func manualCapture() {
        pendingManualCapture = true
    }
    
    private func updatePreviewThumbnail(from buffer: CVPixelBuffer) {
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let context = CIContext(options: nil)
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            DispatchQueue.main.async {
                self.lastTextureImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
            }
        }
    }
}
