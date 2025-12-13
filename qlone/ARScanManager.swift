// ARScanManager.swift

import Foundation
import ARKit
import UIKit
import CoreImage
import Combine
import simd
import SceneKit
import RealityKit
import ModelIO
import SceneKit.ModelIO
import AVFoundation
import SwiftUI

enum CaptureMode {
    case auto
    case manual
}

@MainActor
final class ARScanManager: NSObject, ObservableObject, ARSessionDelegate {
    
    // MARK: - Published UI State
    
    @Published var captureMode: CaptureMode = .auto
    
    @Published var planningMode: PlanningMode = .esthetic
    @Published var captureState: CaptureState = .repose
    @Published var previewMode: PreviewMode = .pointCloud
    
    @Published var isRunning: Bool = false
    @Published var statusText: String = "Ready"
    
    @Published var previewScene: SCNScene?
    @Published var previewGeometry: SCNGeometry?
    
    @Published var azimuthProgress: Float = 0
    @Published var elevationProgress: Float = 0
    
    @Published var qualityScore: Float = 0
    @Published var mouthQualityScore: Float = 0
    @Published var frameCountForState: Int = 0
    
    @Published var highDetailStatus: String = ""
    @Published var isHighDetailReconstructing: Bool = false
    
    @Published var isTorchOn: Bool = false
    @Published var arVideoResolution: ARVideoResolutionPreset = .res4k {
        didSet {
            // Live update while session is running
            guard isRunning,
                  let current = session.configuration as? ARWorldTrackingConfiguration
            else { return }
            
            let config = current
            applyVideoResolutionPreset(arVideoResolution, to: config)
            session.run(config, options: [])        // re-run with new format
            statusText = "Resolution: \(arVideoResolution.label)"
        }
    }

    // Add these two:
    var currentPhotogrammetryTask: Task<Void, Never>?
    var currentPhotogrammetrySession: PhotogrammetrySession?

    // MARK: - Core Engine
    
    let session = ARSession()
    let imageWriter = ImageWriter()
    let reconstruction = ReconstructionPipeline()
    let mouthDetector = MouthDetector()
    let qualityEvaluator = QualityEvaluator()
    
    /// Raw feature points in reference-camera space (global envelope)
    var rawPointsByState: [CaptureState: [SIMD3<Float>]] = [:]
    
    /// Head-gated points in reference-camera space (denser in head region)
    var facePointsByState: [CaptureState: [SIMD3<Float>]] = [:]
    
    var lastTextureImage: UIImage?
    var highDetailModelURL: URL?
    
    // Face lock + reference camera frame
    var faceLockAcquired: Bool = false
    var consecutiveFaceHits: Int = 0
    var referenceCameraTransform: simd_float4x4?
    var referenceCameraInverse: simd_float4x4?
    
    /// Last Vision detection (used both for streaming & manual crops)
    var lastDetection: FaceAndMouthDetection?
    
    /// Time of last still capture written for photogrammetry
    var lastCaptureTimestamp: TimeInterval = 0
    
    /// When true, the next AR frame will be forced to save as a still
    var pendingManualCapture: Bool = false
    // MARK: - Coverage meter internal state

    /// Discrete yaw/pitch buckets we’ve visited so far.
    /// (We’ll use 8 azimuth × 4 elevation bins.)
    var coverageBins: Set<Int> = []

    /// Prevents multiple auto-stops in one run.
    var didAutoStopOnCoverage: Bool = false

    // MARK: - Capture targets
    
    var targetFrameCount: Int {
        switch planningMode {
        case .esthetic: return 80
        case .fullArch: return 120
        }
    }
    
    // MARK: - Throttling
    
    var frameIndex: Int = 0
    let visionStride: Int = 3        // run Vision 1/3 frames
    let previewStride: Int = 4       // rebuild preview 1/4 frames
    
    // MARK: - Init
    
    override init() {
        super.init()
        session.delegate = self
    }
    
    func arSession() -> ARSession { session }
    
    // MARK: - Public control
    
    func start() {
        rawPointsByState[captureState] = []
        facePointsByState[captureState] = []

        frameCountForState = 0
        lastCaptureTimestamp = 0
        lastTextureImage = nil

        referenceCameraTransform = nil
        referenceCameraInverse  = nil

        faceLockAcquired     = false
        consecutiveFaceHits  = 0
        lastDetection        = nil

        highDetailStatus           = ""
        isHighDetailReconstructing = false
        highDetailModelURL         = nil

        previewScene    = nil
        previewGeometry = nil

        // NEW: reset coverage meter
        resetCoverage()

        imageWriter.clearSessionFolder(state: captureState)

        let config = ARWorldTrackingConfiguration()
        config.isLightEstimationEnabled = true
        config.environmentTexturing    = .none
        config.frameSemantics          = []

        // If you’re using the video-resolution preset extension, apply it here:
        // applyVideoResolutionPreset(arVideoResolution, to: config)

        session.run(config, options: [.resetTracking, .removeExistingAnchors])

        isRunning  = true
        statusText = "Align patient face in view"
    }



    
    
    func stop() {
        session.pause()
        isRunning = false
        setTorch(enabled: false)
        statusText = "Scan stopped"
    }
    
    func resetStateSamples() {
        rawPointsByState[captureState]  = []
        facePointsByState[captureState] = []
        frameCountForState              = 0
        lastCaptureTimestamp            = 0
        lastTextureImage                = nil

        referenceCameraTransform = nil
        referenceCameraInverse  = nil

        faceLockAcquired    = false
        consecutiveFaceHits = 0
        lastDetection       = nil

        highDetailStatus           = ""
        isHighDetailReconstructing = false
        highDetailModelURL         = nil

        previewScene    = nil
        previewGeometry = nil

        // NEW: reset coverage meter
        resetCoverage()

        imageWriter.clearSessionFolder(state: captureState)
        statusText = "Reset \(captureState.rawValue)"
    }
    
    // MARK: - Manual shutter entry point (for UI)
    
    /// Called from the camera-circle button in ScanView when in Manual mode.
    /// It does **not** block the UI; the next good AR frame will be stored
    /// by the capture pipeline (`processFrame` in ARScanManager+Capture.swift).
 
    
    // MARK: - Torch
    
    func setTorch(enabled: Bool) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .back),
              device.hasTorch else {
            isTorchOn = false
            return
        }
        
        do {
            try device.lockForConfiguration()
            if enabled {
                if device.torchMode != .on {
                    try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                }
            } else {
                if device.torchMode != .off {
                    device.torchMode = .off
                }
            }
            device.unlockForConfiguration()
            isTorchOn = enabled
        } catch {
            isTorchOn = (device.torchMode == .on)
        }
    }
    func cancelHighDetailReconstruction(deleteCaptures: Bool) {
        // Cancel the long-running task & session if they exist
        currentPhotogrammetrySession?.cancel()
        currentPhotogrammetryTask?.cancel()

        currentPhotogrammetrySession = nil
        currentPhotogrammetryTask = nil

        isHighDetailReconstructing = false
        highDetailStatus = "Photogrammetry cancelled"
        statusText = highDetailStatus

        if deleteCaptures {
            // Wipe images for the *current* capture state
            imageWriter.clearSessionFolder(state: captureState)
            frameCountForState = 0
            lastTextureImage = nil
        }

        // Optional: also clear preview
        previewScene = nil
        previewGeometry = nil
        highDetailModelURL = nil
    }
    
}
