// ARScanManager+HighResManual.swift
import Foundation
import ARKit
import UIKit
import AVFoundation

@MainActor
extension ARScanManager {

    /// Manual still for the face / global head, triggered by the main shutter
    /// when you are in Manual mode. Uses full-resolution photo capture.
    func manualCapture() {
        guard isRunning else { return }

        HighResPhotoCapture.shared.capture { [weak self] image in
            guard let self, let image = image else { return }

            // Save into the current captureState (repose / smile / etc.)
            _ = self.imageWriter.write(image: image, state: self.captureState)
            self.frameCountForState += 1
            self.lastTextureImage = image

            let frac = min(
                1.0,
                Float(self.frameCountForState) / Float(self.targetFrameCount)
            )
            self.azimuthProgress = frac
            self.elevationProgress = frac

            self.statusText = "Manual photo captured"
        }
    }

    // ⚠️ DO NOT put manualMacroCapture() in this file anymore.
}
