import Foundation
import UIKit
import CoreImage
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

/// Handles writing Max-Quality JPEG images and Float32 Depth TIFFs.
actor ImageWriter {
    
    private let fm = FileManager.default
    // Use CIContext for robust color/format conversion
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
    
    func write(colorBuffer: CVPixelBuffer,
               metadata: [String: Any]?,
               rawDepthBuffer: CVPixelBuffer?,
               state: CaptureState) {
        
        let folder = sessionFolder(state: state)
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let baseFilename = "img_\(timestamp)"
        
        // SWITCH TO JPEG (Fixes "Failed to read sample")
        let imageURL = folder.appendingPathComponent("\(baseFilename).jpeg")
        
        // 1. PREPARE METADATA
        var finalMetadata = metadata ?? [:]
        finalMetadata[kCGImagePropertyOrientation as String] = 6
        // MAX QUALITY (1.0) - effectively lossless for Photogrammetry
        finalMetadata[kCGImageDestinationLossyCompressionQuality as String] = 1.0
        
        // 2. WRITE JPEG (Color)
        // Use CIContext -> CGImage for maximum stability (prevents corrupted writes)
        let ciImage = CIImage(cvPixelBuffer: colorBuffer)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent, format: .RGBA8, colorSpace: colorSpace) {
            if let dest = CGImageDestinationCreateWithURL(imageURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) {
                CGImageDestinationAddImage(dest, cgImage, finalMetadata as CFDictionary)
                if !CGImageDestinationFinalize(dest) {
                    print("❌ Failed to finalize JPEG")
                }
            }
        }
        
        // 3. WRITE DEPTH TIFF (Float32) - "Raw Data" for macOS
        if let depthMap = rawDepthBuffer {
            let depthURL = folder.appendingPathComponent("\(baseFilename)_depth.tiff")
            
            let depthImage = CIImage(cvPixelBuffer: depthMap)
                .settingProperties([kCGImagePropertyOrientation as String : 6])
            
            do {
                // Use Float32 (.Rf) to preserve real-world metric depth
                try context.writeTIFFRepresentation(
                    of: depthImage,
                    to: depthURL,
                    format: .Rf,
                    colorSpace: CGColorSpace(name: CGColorSpace.linearGray)!,
                    options: [:]
                )
            } catch {
                print("❌ Write Error (Depth TIFF): \(error)")
            }
        }
    }
}
