// ARScanManager+Capture.swift
import Foundation
import ARKit
import UIKit

@MainActor
extension ARScanManager {

    // MARK: - ARSessionDelegate entry point

    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isRunning else { return }

        let auto = (captureMode == .auto)

        // If a manual capture was requested, we force exactly one still on this frame.
        let force = pendingManualCapture
        if pendingManualCapture {
            pendingManualCapture = false
        }

        processFrame(frame,
                     autoTrigger: auto,
                     forceCaptureStill: force)
    }

    /// Core per-frame processing.
    ///
    /// - `autoTrigger`: whether automatic still capture is allowed for this frame.
    /// - `forceCaptureStill`: true when the user pressed the manual shutter; bypasses
    ///   normal quality logic (we still keep basic sanity checks).
    func processFrame(_ frame: ARFrame,
                      autoTrigger: Bool,
                      forceCaptureStill: Bool) {

        frameIndex &+= 1

        let pixelBuffer = frame.capturedImage
        guard let uiImage = Self.image(from: pixelBuffer) else { return }
        let imageSize = uiImage.size

        // --- Vision face + landmarks (throttled) ---

        let detection: FaceAndMouthDetection?
        if frameIndex % visionStride == 0 {
            let det = mouthDetector.detectFaceAndMouth(in: uiImage)
            lastDetection = det
            detection = det
        } else {
            detection = lastDetection
        }

        updateFaceLock(from: detection)

        // --- Head rect (pixels & normalized) for gating only (NOT for cropping) ---

        let headRectPx: CGRect?
        if let faceRect = detection?.faceBoundingBox {
            headRectPx = headRect(fromFaceRect: faceRect, imageSize: imageSize)
        } else {
            headRectPx = nil
        }

        let headRectNorm: CGRect?
        if let r = headRectPx {
            headRectNorm = CGRect(
                x: r.origin.x / imageSize.width,
                y: r.origin.y / imageSize.height,
                width: r.size.width / imageSize.width,
                height: r.size.height / imageSize.height
            )
        } else {
            headRectNorm = nil
        }

        // --- Quality scores ---

        let mouthROI = detection?.mouthROI
        qualityScore = qualityEvaluator.score(image: uiImage, mouthROI: mouthROI)
        mouthQualityScore = qualityEvaluator.mouthSpecificScore(image: uiImage,
                                                                mouthROI: mouthROI)

        // --- Reference camera for stabilized point cloud ---

        if faceLockAcquired {
            if referenceCameraTransform == nil {
                referenceCameraTransform = frame.camera.transform
                referenceCameraInverse = simd_inverse(frame.camera.transform)
            }
        } else {
            referenceCameraTransform = nil
            referenceCameraInverse = nil
        }

        // --- Decide whether to capture a still for photogrammetry ---

        let now = frame.timestamp

        // A bit stricter to avoid blurry frames.
        let minInterval: Double = 0.18       // slightly faster, still safe
        let minQuality: Float = 0.65         // reject softer frames
        let minMouthQuality: Float = 0.55     // keep only crisp mouth area

        var shouldSaveStill = false

        if forceCaptureStill {
            // Manual shutter: always save *a* frame, but still require face lock
            // so we don't capture a random wall.
            if faceLockAcquired {
                shouldSaveStill = true
            }
        } else if autoTrigger {
            if now - lastCaptureTimestamp >= minInterval,
               faceLockAcquired,
               qualityScore >= minQuality,
               mouthQualityScore >= minMouthQuality {
                shouldSaveStill = true
            }
        }

        if shouldSaveStill {
            lastCaptureTimestamp = now

            // DO NOT CROP – full frame for photogrammetry
            let imageToSave = uiImage

            _ = imageWriter.write(image: imageToSave, state: captureState)
            frameCountForState += 1
            lastTextureImage = imageToSave

            let frac = min(1.0,
                           Float(frameCountForState) / Float(targetFrameCount))
            azimuthProgress = frac
            elevationProgress = frac

            statusText = forceCaptureStill
                ? "Manual photo captured"
                : "Frame \(frameCountForState) captured"
        }

        // --- Raw feature points for global envelope ---

        if let pointCloud = frame.rawFeaturePoints {
            let worldPoints = pointCloud.points

            if !worldPoints.isEmpty {
                var transformed: [SIMD3<Float>] = []
                transformed.reserveCapacity(worldPoints.count)
                for p in worldPoints {
                    transformed.append(transformToReferenceSpace(p))
                }

                var raw = rawPointsByState[captureState] ?? []
                raw.append(contentsOf: transformed)

                let maxPoints = 600_000   // global envelope cap
                if raw.count > maxPoints {
                    raw = Array(raw.suffix(maxPoints))
                }
                rawPointsByState[captureState] = raw
            }

            // --- Head-gated points (denser sampling inside head region) ---

            if let headNorm = headRectNorm {
                let expandedHead = expandedRect(headNorm, factor: 1.15)
                let allPoints = worldPoints

                if !allPoints.isEmpty {
                    var faceArr = facePointsByState[captureState] ?? []

                    for (idx, p) in allPoints.enumerated() {
                        guard let ptPx = projectToImagePoint(
                            worldPoint: p,
                            frame: frame,
                            imageSize: imageSize
                        ) else { continue }

                        let ptNorm = CGPoint(
                            x: ptPx.x / imageSize.width,
                            y: ptPx.y / imageSize.height
                        )

                        guard expandedHead.contains(ptNorm) else { continue }

                        // Keep ~70% in head region for a denser, smoother preview.
                        let keep = (idx % 3 != 0)
                        if keep {
                            faceArr.append(transformToReferenceSpace(p))
                        }
                    }

                    let maxPoints = 350_000   // head-region cap
                    if faceArr.count > maxPoints {
                        faceArr = Array(faceArr.suffix(maxPoints))
                    }
                    facePointsByState[captureState] = faceArr
                }
            }
        }

        // --- Live preview mesh (throttled) ---

        if frameIndex % previewStride == 0 {
            updatePreviewGeometry()
        }
        if faceLockAcquired {
            updateCoverage(from: frame)
        }
    }

    // MARK: - Face lock (unchanged logic, kept in extension)

    func updateFaceLock(from detection: FaceAndMouthDetection?) {
        guard let detection else {
            consecutiveFaceHits = max(0, consecutiveFaceHits - 1)
            if consecutiveFaceHits == 0 {
                faceLockAcquired = false
            }
            return
        }

        if detection.confidence > 0.6 {
            consecutiveFaceHits += 1
        } else {
            consecutiveFaceHits = max(0, consecutiveFaceHits - 1)
        }

        if !faceLockAcquired, consecutiveFaceHits > 8 {
            faceLockAcquired = true
            statusText = "Face locked – start sweeping"
        }
    }
    // Pseudo-code – only if we decide to do this
 
     
}
