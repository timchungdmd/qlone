import ARKit
import simd
import CoreGraphics

@MainActor
extension ARScanManager {

    /// Yaw (azimuth) and pitch (elevation) of the current camera
    /// in radians, relative to a reference camera transform.
    func cameraAngles(relativeTo ref: simd_float4x4,
                      current: simd_float4x4) -> (azimuth: Float, elevation: Float) {

        // Current camera transform expressed in reference-camera space.
        let rel = simd_mul(simd_inverse(ref), current)

        // Camera forward vector (-Z in camera space)
        let forward = SIMD3<Float>(
            -rel.columns.2.x,
            -rel.columns.2.y,
            -rel.columns.2.z
        )

        // Azimuth: rotation around vertical axis (-π … +π)
        let azimuth = atan2f(forward.x, forward.z)

        // Elevation: rotation up/down (-π/2 … +π/2)
        let clampedY = max(-1.0 as Float, min(1.0 as Float, forward.y))
        let elevation = asinf(clampedY)

        return (azimuth, elevation)
    }

    /// Update the azimuth/elevation coverage meter using an AR frame.
    /// Uses an 8×4 grid of yaw/pitch bins and writes into `azimuthProgress`
    /// and `elevationProgress` as a single 0…1 coverage value.
    func updateCoverage(from frame: ARFrame) {
        guard let ref = referenceCameraTransform else { return }

        let angles = cameraAngles(
            relativeTo: ref,
            current: frame.camera.transform
        )

        let azBins = 8  // columns in yaw
        let elBins = 4  // rows in pitch

        // Normalise angles to [0, 1)
        let normAz = (angles.azimuth + Float.pi) / (2 * Float.pi)        // 0…1
        let normEl = (angles.elevation + Float.pi / 2) / Float.pi        // 0…1

        let aIdx = max(0, min(azBins - 1, Int(normAz * Float(azBins))))
        let eIdx = max(0, min(elBins - 1, Int(normEl * Float(elBins))))

        let key = eIdx * azBins + aIdx
        coverageBins.insert(key)

        let totalBins = azBins * elBins
        let coverage  = Float(coverageBins.count) / Float(totalBins)

        // Reuse these as a coverage bar (0 = poor, 1 = full sphere).
        azimuthProgress   = coverage
        elevationProgress = coverage

        // Auto-stop behaviour in Auto mode once we have "enough" coverage.
        // Require some minimum number of frames so we don't stop too early.
        if captureMode == .auto,
           !didAutoStopOnCoverage,
           coverage >= 0.85,                    // 85% of bins covered
           frameCountForState >= targetFrameCount / 2 {

            didAutoStopOnCoverage = true
            statusText            = "Coverage complete – auto stop"
            stop()
        }
    }

    /// Reset coverage state (called from start()/resetStateSamples()).
    func resetCoverage() {
        coverageBins.removeAll()
        didAutoStopOnCoverage = false
        azimuthProgress       = 0
        elevationProgress     = 0
    }
}
