import ARKit
import simd

/// Converts camera pose into coarse azimuth/elevation bins
/// so we can track coverage of viewpoints.
final class PoseBinner {
    func resetReference() {
        // Currently unused; placeholder for future relative-pose logic
    }
    
    func bins(from frame: ARFrame,
              azBins: Int,
              elBins: Int) -> (Int, Int) {
        let t = frame.camera.transform
        
        // Camera forward is negative Z in ARKit
        let forward = SIMD3<Float>(-t.columns.2.x, -t.columns.2.y, -t.columns.2.z)
        let f = simd_normalize(forward)
        
        // Yaw (around y)
        let yaw = atan2(f.x, f.z)                     // -π .. π
        let yawNorm = (yaw + .pi) / (2 * .pi)         // 0..1
        
        // Pitch (around x)
        let pitch = asin(max(-1.0, min(1.0, f.y)))    // -π/2 .. π/2
        let pitchNorm = (pitch + (.pi / 2)) / .pi     // 0..1
        
        func clampBin(_ value: Float, bins: Int) -> Int {
            if bins <= 1 { return 0 }
            let idx = Int(value * Float(bins))
            return max(0, min(bins - 1, idx))
        }
        
        let az = clampBin(yawNorm, bins: azBins)
        let el = clampBin(pitchNorm, bins: elBins)
        return (az, el)
    }
}
