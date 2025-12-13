// ARScanManager+VideoResolution.swift
import ARKit
import CoreGraphics

/// Logical presets for AR video resolution.
enum ARVideoResolutionPreset: CaseIterable {
    case res4k      // highest
    case res2k
    case res1k
}

extension ARVideoResolutionPreset {
    /// Label if you ever want to show text instead of icons.
    var label: String {
        switch self {
        case .res4k: return "4K"
        case .res2k: return "2K"
        case .res1k: return "1K"
        }
    }
    
    /// Minimum *width* in pixels we want for this preset.
    /// ARKit will choose the smallest format whose width >= this value.
    var minWidth: CGFloat {
        switch self {
        case .res4k: return 3500    // ~4K
        case .res2k: return 1900    // ~2K
        case .res1k: return 1200    // ~1K
        }
    }
}

extension ARScanManager {
    
    /// Choose the best ARKit video format for the given preset.
    /// Picks the *smallest* format whose width >= preset.minWidth,
    /// or falls back to the highest available.
    func bestVideoFormat(for preset: ARVideoResolutionPreset)
    -> ARConfiguration.VideoFormat? {
        
        let formats = ARWorldTrackingConfiguration.supportedVideoFormats
        
        // Sort by width so we can find the smallest that satisfies minWidth.
        let sorted = formats.sorted {
            $0.imageResolution.width < $1.imageResolution.width
        }
        
        let targetWidth = preset.minWidth
        
        if let match = sorted.first(where: {
            CGFloat($0.imageResolution.width) >= targetWidth
        }) {
            return match
        } else {
            return sorted.last
        }
    }
    
    /// Apply the current preset to an ARWorldTrackingConfiguration.
    func applyVideoResolutionPreset(_ preset: ARVideoResolutionPreset,
                                    to configuration: ARWorldTrackingConfiguration) {
        if let format = bestVideoFormat(for: preset) {
            configuration.videoFormat = format
        }
    }
}
