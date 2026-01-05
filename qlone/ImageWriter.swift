import Foundation
import UIKit

/// Handles writing images to disk.
/// ADOPTED FROM ORIGINAL: Writes JPEGs to ensure correct orientation and compatibility.
actor ImageWriter {
    
    private let fm = FileManager.default
    
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
        // Remove content, keep folder
        if let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
            for file in files {
                try? fm.removeItem(at: file)
            }
        }
    }
    
    // MARK: - Writing Logic (JPEG)
    
    /// Writes a UIImage as high-quality JPEG (0.95).
    /// This fixes the rotation/metadata bugs found in HEIC.
    func write(image: UIImage, state: CaptureState) {
        let folder = sessionFolder(state: state)
        
        // Simple timestamp-based name
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let filename = "img_\(timestamp).jpg"
        let url = folder.appendingPathComponent(filename)
        
        // 0.95 quality is excellent for photogrammetry
        guard let data = image.jpegData(compressionQuality: 0.95) else { return }
        
        do {
            try data.write(to: url, options: [.atomic])
        } catch {
            print("ImageWriter Error: \(error)")
        }
    }
}
