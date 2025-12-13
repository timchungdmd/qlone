// ARScanManager+MacroTeeth.swift
import Foundation
import ARKit
import UIKit
import AVFoundation

@MainActor
extension ARScanManager {

    /// Aggressive macro still for teeth.
    /// Uses high ISO + fast shutter to reduce motion blur.
    func manualMacroCapture() {
        guard isRunning else { return }

        HighResPhotoCapture.shared.captureFast(
            iso: 1200,                                   // high ISO for speed
            minShutter: CMTimeMake(value: 1, timescale: 750) // ~1/750s
        ) { (image: UIImage?) in
            guard let image = image else { return }

            // Save into teeth-macro capture bucket
            _ = self.imageWriter.write(
                image: image,
                state: CaptureState.teethMacro
            )

            self.statusText = "Macro teeth photo captured"
        }
    }
}
