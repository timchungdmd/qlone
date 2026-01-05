import Foundation
import UIKit
import CoreImage
import AVFoundation
import ImageIO
import UniformTypeIdentifiers
import VideoToolbox // Essential for fast CGImage conversion

/// Handles writing HEIC images and Depth data with Metadata.
actor ImageWriter {
    
    private let fm = FileManager.default
    private let context = CIContext(options: [.cacheIntermediates: false])
    
    // MARK: - Paths
    
    private var baseFolder: URL {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = docs.appendingPathComponent("Captures", isDirectory: true)
        if !fm.fileExists(atPath: folder.path) {
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }
    
    func sessionFolder(state: CaptureState) -> URL {
        let folder = baseFolder.appendingPathComponent(state.rawValue, isDirectory: true)
        if !fm.fileExists(atPath: folder.path) {
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }
    
    func photogrammetryInputFolder(for state: CaptureState) -> URL {
        let base = sessionFolder(state: state)
        let folder = base.appendingPathComponent("PhotogrammetryInput", isDirectory: true)
        if !fm.fileExists(atPath: folder.path) {
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }
    
    func clearSessionFolder(state: CaptureState) {
        let folder = sessionFolder(state: state)
        if let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
            for file in files {
                try? fm.removeItem(at: file)
            }
        }
    }
    
    // MARK: - Writing Logic
    
    /// Writes image and depth data to disk, preserving ARKit Metadata.
    func write(colorBuffer: CVPixelBuffer,
               metadata: [String: Any]?,
               rawDepthBuffer: CVPixelBuffer?,
               state: CaptureState) {
        
        let folder = sessionFolder(state: state)
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let baseFilename = "img_\(timestamp)"
        
        let imageURL = folder.appendingPathComponent("\(baseFilename).heic")
        
        // 1. PREPARE METADATA (Critical for Gravity/Orientation)
        var finalMetadata = metadata ?? [:]
        // Force Orientation 6 (Right) because ARKit buffers are landscape
        finalMetadata[kCGImagePropertyOrientation as String] = 6
        
        // 2. WRITE HEIC (Color + Metadata)
        // Use VideoToolbox for efficient CVPixelBuffer -> CGImage conversion
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(colorBuffer, options: nil, imageOut: &cgImage)
        
        if let image = cgImage {
            if let dest = CGImageDestinationCreateWithURL(imageURL as CFURL, UTType.heic.identifier as CFString, 1, nil) {
                // This injects the Gravity Vector and Orientation
                CGImageDestinationAddImage(dest, image, finalMetadata as CFDictionary)
                if !CGImageDestinationFinalize(dest) {
                    print("❌ Failed to finalize HEIC")
                }
            }
        }
        
        // 3. WRITE DEPTH TIFF (If available)
        if let depthMap = rawDepthBuffer {
            let depthURL = folder.appendingPathComponent("\(baseFilename)_depth.tiff")
            
            // Apply Orientation 6 to Depth so it aligns with Color
            let depthImage = CIImage(cvPixelBuffer: depthMap)
                .settingProperties([kCGImagePropertyOrientation as String : 6])
            
            do {
                // Use Linear Gray for accurate 16-bit depth values
                // Safe fallback for ColorSpace
                let depthColorSpace = CGColorSpace(name: CGColorSpace.linearGray) ?? CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)!
                
                try context.writeTIFFRepresentation(
                    of: depthImage,
                    to: depthURL,
                    format: .L16, // 16-bit Grayscale
                    colorSpace: depthColorSpace,
                    options: [:]
                )
            } catch {
                print("❌ Write Error (Depth TIFF): \(error)")
            }
        }
    }
}
