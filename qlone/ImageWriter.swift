// ImageWriter.swift
import Foundation
import UIKit

/// Handles writing still images to disk per CaptureState,
/// and provides folders for photogrammetry input.
final class ImageWriter {
    
    private let fm = FileManager.default
    
    // Base folder for all capture sessions
    private var baseFolder: URL {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = docs.appendingPathComponent("Captures", isDirectory: true)
        if !fm.fileExists(atPath: folder.path) {
            try? fm.createDirectory(at: folder,
                                    withIntermediateDirectories: true,
                                    attributes: nil)
        }
        return folder
    }
    
    /// Folder for a given captureState (e.g. "repose", "smile", "teeth", ...)
    func sessionFolder(state: CaptureState) -> URL {
        let folder = baseFolder.appendingPathComponent(state.rawValue,
                                                       isDirectory: true)
        if !fm.fileExists(atPath: folder.path) {
            try? fm.createDirectory(at: folder,
                                    withIntermediateDirectories: true,
                                    attributes: nil)
        }
        return folder
    }
    
    /// Folder used as input to PhotogrammetrySession for this state.
    func photogrammetryInputFolder(for state: CaptureState) -> URL {
        let base = sessionFolder(state: state)
        let folder = base.appendingPathComponent("PhotogrammetryInput",
                                                 isDirectory: true)
        if !fm.fileExists(atPath: folder.path) {
            try? fm.createDirectory(at: folder,
                                    withIntermediateDirectories: true,
                                    attributes: nil)
        }
        return folder
    }
    
    /// Remove all images for this state (used when starting / resetting a scan).
    func clearSessionFolder(state: CaptureState) {
        let folder = sessionFolder(state: state)
        do {
            let contents = try fm.contentsOfDirectory(at: folder,
                                                      includingPropertiesForKeys: nil,
                                                      options: [.skipsHiddenFiles])
            for url in contents {
                try? fm.removeItem(at: url)
            }
        } catch {
            // ignore – folder may not exist yet
        }
    }
    
    /// Write a UIImage as high-quality JPEG; returns the URL on success.
    ///
    /// IMPORTANT: we do *not* rescale – we preserve the full pixel resolution
    /// of the input UIImage. JPEG quality set high (0.95) for photogrammetry.
    @discardableResult
    func write(image: UIImage, state: CaptureState) -> URL? {
        let folder = sessionFolder(state: state)
        
        // Simple timestamp-based name to avoid collisions
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let filename = "img_\(timestamp).jpg"
        let url = folder.appendingPathComponent(filename)
        
        guard let data = image.jpegData(compressionQuality: 0.95) else {
            return nil
        }
        
        do {
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            print("ImageWriter: failed to write image:", error)
            return nil
        }
    }
    
}
