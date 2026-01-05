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
    
    // --- RESTORED MISSING VARIABLE ---
    @Published var lastTextureImage: UIImage?
    @Published var previewMode: String = "Mesh" // Often used by preview logic
    
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
        // Small delay to allow session to tear down before restarting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.start()
        }
    }
    
    func start() {
        // 1. CHOOSE CONFIGURATION
        let config: ARConfiguration
        
        if useFrontCamera {
            // --- SELFIE MODE ---
            guard ARFaceTrackingConfiguration.isSupported else {
                statusText = "Face ID not available"
                return
            }
            let faceConfig = ARFaceTrackingConfiguration()
            faceConfig.isLightEstimationEnabled = true
            
            // Try to find best resolution for Front Camera
            if let best = ARFaceTrackingConfiguration.supportedVideoFormats.max(by: {
                $0.imageResolution.height < $1.imageResolution.height
            }) {
                faceConfig.videoFormat = best
            }
            
            config = faceConfig
            statusText = "Selfie Mode"
            
        } else {
            // --- REAR CAMERA (HIGH RES) ---
            guard ARWorldTrackingConfiguration.isSupported else {
                statusText = "AR not supported"
                return
            }
            let worldConfig = ARWorldTrackingConfiguration()
            worldConfig.isAutoFocusEnabled = true
            
            // Force 4K Resolution (3840x2160 usually)
            if let best = ARWorldTrackingConfiguration.supportedVideoFormats.max(by: {
                ($0.imageResolution.width * $0.imageResolution.height) <
                ($1.imageResolution.width * $1.imageResolution.height)
            }) {
                worldConfig.videoFormat = best
                print("Rear Camera: \(best.imageResolution)")
            }
            
            config = worldConfig
            statusText = "Rear 4K Mode"
        }
        
        // 2. RUN
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
        
        // Reset tracking vars
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
