import Foundation
import ARKit
import SceneKit
import SwiftUI // <--- ADD THIS IMPORT

extension ARScanManager {
    
    /// Called from +Capture.swift to update coverage stats
    func updateCoverage(from frame: ARFrame) {
        // 1. Setup Reference Frame (First Frame)
        guard let currentTransform = frame.anchors.first(where: { $0 is ARFaceAnchor })?.transform else { return }
        
        if referenceCameraTransform == nil {
            referenceCameraTransform = currentTransform
            referenceCameraInverse = currentTransform.inverse
            return
        }
        
        // 2. Calculate Relative Position
        guard let refInverse = referenceCameraInverse else { return }
        let relativeTransform = refInverse * currentTransform
        
        // 3. Extract Angles (Azimuth/Elevation)
        // Extract rotation from the matrix
        let pitch = -asin(relativeTransform.columns.2.y)
        let yaw = atan2(relativeTransform.columns.2.x, relativeTransform.columns.2.z)
        
        // Convert to degrees for easier binning
        let azimuth = Int(yaw * 180 / .pi)
        let elevation = Int(pitch * 180 / .pi)
        
        // 4. Quantize into Bins (e.g., every 10 degrees)
        // We use String keys like "10_20" (Azimuth_Elevation)
        let azimuthBin = (azimuth / 10) * 10
        let elevationBin = (elevation / 10) * 10
        let binKey = "\(azimuthBin)_\(elevationBin)"
        
        // 5. Update State
        if !coverageBins.contains(binKey) {
            coverageBins.insert(binKey)
            
            // Normalize progress 0.0 to 1.0 based on arbitrary target of unique bins
            // This is a heuristic for UI feedback
            withAnimation {
                self.azimuthProgress = min(Float(coverageBins.count) / 20.0, 1.0)
                self.elevationProgress = min(Float(coverageBins.count) / 20.0, 1.0)
            }
        }
        
        // 6. Check for Completion (Auto-Stop)
        if captureMode == .auto && !didAutoStopOnCoverage {
            if frameCountForState >= targetFrameCount {
                didAutoStopOnCoverage = true
                self.stop()
                self.statusText = "Scan Complete!"
            }
        }
    }
}
