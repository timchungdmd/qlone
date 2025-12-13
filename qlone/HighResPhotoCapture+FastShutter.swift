// HighResPhotoCapture+FastShutter.swift
import AVFoundation

extension HighResPhotoCapture {
    
    /// Try to bias the still-photo camera toward a *fast* shutter
    /// by using a custom exposure with higher ISO.
    ///
    /// Call this right before macro / teeth captures, e.g.
    /// `HighResPhotoCapture.shared.configureFastShutterForMacro()`
    /// from ARScanManager when starting macro mode.
    func configureFastShutterForMacro() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .back)
        else { return }
        
        do {
            try device.lockForConfiguration()
            
            let format = device.activeFormat
            
            // Desired shutter: e.g. ~1/500s to freeze motion.
            // Must be >= minExposureDuration.
            let desired = CMTime(value: 1, timescale: 500)  // 1/500s
            let minAllowed = format.minExposureDuration     // fastest the HW supports
            let duration = CMTimeMaximum(minAllowed, desired)
            
            // ISO: allow some boost but not insane (noise = bumpy mesh)
            let maxISO = min(format.maxISO, 800)  // cap at ~800 for now
            let baseISO = max(format.minISO, 400) // push slightly above base
            let iso = min(maxISO, baseISO)
            
            if device.isExposureModeSupported(.custom) {
                device.setExposureModeCustom(duration: duration,
                                             iso: iso,
                                             completionHandler: nil)
            }
            
            // Optional: lock focus near macro as well
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Fast shutter config failed:", error)
        }
    }
}
