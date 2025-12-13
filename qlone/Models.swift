import Foundation
import CoreGraphics

// MARK: - High-level planning modes

enum PlanningMode: String, CaseIterable, Codable {
    case esthetic
    case fullArch
    
    var recipe: PlanningRecipe {
        switch self {
        case .esthetic:
            return PlanningRecipe(
                requiredAzimuthBins: 5,
                requiredElevationBins: 2,
                minQuality: 0.35,
                minMouthQuality: 0.30
            )
        case .fullArch:
            return PlanningRecipe(
                requiredAzimuthBins: 7,
                requiredElevationBins: 3,
                minQuality: 0.40,
                minMouthQuality: 0.35
            )
        }
    }
}

// MARK: - Capture state & preview mode

enum CaptureState: String, CaseIterable {
    case repose
    case smile
    case profile
    // ...
    case teethMacro      // <-- add this
}


enum PreviewMode: String, CaseIterable, Codable {
    case pointCloud
    case sparseMesh
    case denseMesh
}

// MARK: - Recipes and stored samples

struct PlanningRecipe: Codable {
    var requiredAzimuthBins: Int
    var requiredElevationBins: Int
    var minQuality: Float
    var minMouthQuality: Float
}

struct FrameSample: Codable {
    var timestamp: TimeInterval
    var cameraTransform: [[Float]]
    var cameraIntrinsics: [[Float]]
    var imageFile: String
    var qualityScore: Float
    var mouthQualityScore: Float
    var mouthROINormalized: [Float]
}

struct StateCaptureBundle: Codable {
    var planningMode: String
    var captureState: String
    var createdAtISO8601: String
    var samples: [FrameSample]
}

// MARK: - Detection & export models

struct FaceAndMouthDetection {
    var faceBoundingBox: CGRect       // normalized 0–1
    var mouthROI: CGRect?             // normalized 0–1
    var confidence: Float
}

enum MeshExportFormat {
    case obj
    case ply
    case stl
    
    var fileExtension: String {
        switch self {
        case .obj: return "obj"
        case .ply: return "ply"
        case .stl: return "stl"
        }
    }
}
