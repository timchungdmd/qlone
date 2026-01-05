import Foundation
import ARKit
import SceneKit
import SwiftUI
import Combine

@MainActor
class ARScanManager: NSObject, ObservableObject, ARSessionDelegate {
    
    // --- AR Session ---
    let session = ARSession()
    let imageWriter = ImageWriter()
    
    // --- State ---
    @Published var statusText: String = "Ready"
    @Published var isRunning: Bool = false
    
    // Camera Toggle (Default: False = Rear Camera)
    @Published var useFrontCamera: Bool = false
    
    // Capture State
    @Published var captureState: CaptureState = .smile
    @Published var captureMode: CaptureMode = .auto
    
    @Published var frameCountForState: Int = 0
    @Published var lastCaptureTimestamp: TimeInterval = 0
    @Published var pendingManualCapture: Bool = false
    
    // Visuals & Preview
    @Published var previewScene: SCNScene?
    @Published var referenceCameraTransform: matrix_float4x4?
    @Published var isHighDetailReconstructing: Bool = false
    @Published var highDetailStatus: String = ""
    @Published var highDetailModelURL: URL?
    
    @Published var lastTextureImage: UIImage?
    @Published var previewMode: String = "Mesh"
    
    // Coverage Tracking
    @Published var referenceCameraInverse: matrix_float4x4?
    @Published var coverageBins: Set<String> = []
    @Published var azimuthProgress: Float = 0.0
    @Published var elevationProgress: Float = 0.0
    @Published var didAutoStopOnCoverage: Bool = false
    @Published var targetFrameCount: Int = 150
    @Published var previewGeometry: ARSCNFaceGeometry?
    @Published var facePointsByState: [CaptureState: [SIMD3<Float>]] = [:]
    @Published var rawPointsByState: [CaptureState: [SIMD3<Float>]] = [:]

    
    override init() {
        super.init()
        session.delegateQueue = .main
        session.delegate = self
        Task { await imageWriter.clearSessionFolder(state: .smile) }
    }
    
    // MARK: - Lifecycle & Camera Switching
    
    func toggleCamera() {
        useFrontCamera.toggle()
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.start()
        }
    }
    
    func start() {
        let config: ARConfiguration
        
        if useFrontCamera {
            // --- SELFIE MODE (TrueDepth) ---
            guard ARFaceTrackingConfiguration.isSupported else {
                statusText = "Face ID not available"
                return
            }
            let faceConfig = ARFaceTrackingConfiguration()
            faceConfig.isLightEstimationEnabled = true
            // TrueDepth data (capturedDepthData) is available by default in face tracking
            
            // Try to find best resolution
            if let best = ARFaceTrackingConfiguration.supportedVideoFormats.max(by: {
                $0.imageResolution.height < $1.imageResolution.height
            }) {
                faceConfig.videoFormat = best
            }
            
            config = faceConfig
            statusText = "Selfie Mode"
            
        } else {
            // --- REAR CAMERA (LiDAR) ---
            guard ARWorldTrackingConfiguration.isSupported else {
                statusText = "AR not supported"
                return
            }
            let worldConfig = ARWorldTrackingConfiguration()
            worldConfig.isAutoFocusEnabled = true
            
            // 1. Force 4K Resolution if available
            if let best = ARWorldTrackingConfiguration.supportedVideoFormats.max(by: {
                ($0.imageResolution.width * $0.imageResolution.height) <
                ($1.imageResolution.width * $1.imageResolution.height)
            }) {
                worldConfig.videoFormat = best
                print("Rear Camera: \(best.imageResolution)")
            }
            
            // 2. ENABLE LIDAR DEPTH
            if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
                worldConfig.frameSemantics.insert(.sceneDepth)
                // Optional: smoothedSceneDepth fills holes but might blur edges
                // worldConfig.frameSemantics.insert(.smoothedSceneDepth)
                print("LiDAR Scene Depth Enabled")
            }
            
            config = worldConfig
            statusText = "Rear 4K Mode"
        }
        
        // RUN
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        isRunning = true
        
        // Reset counters
        referenceCameraTransform = nil
    }
    
    func stop() {
        session.pause()
        isRunning = false
        statusText = "Paused"
    }
    
    func restart() {
        stop()
        resetState()
        Task { await imageWriter.clearSessionFolder(state: captureState) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.start() }
    }
    
    func resetState() {
        frameCountForState = 0
        statusText = "Ready to Scan"
        previewScene = nil
        highDetailModelURL = nil
        isHighDetailReconstructing = false
        lastTextureImage = nil
        
        facePointsByState.removeAll()
        rawPointsByState.removeAll()
        referenceCameraInverse = nil
        referenceCameraTransform = nil
        coverageBins.removeAll()
        azimuthProgress = 0
        elevationProgress = 0
        didAutoStopOnCoverage = false
    }
}
