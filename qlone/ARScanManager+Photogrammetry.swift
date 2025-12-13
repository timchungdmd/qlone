// ARScanManager+Photogrammetry.swift
import Foundation
import SceneKit
import RealityKit
import UIKit
import CoreImage

extension ARScanManager {
    
    // MARK: - High-detail photogrammetry
    
    /// Build a high-detail mesh from the stills for the current `captureState`.
    /// Input images are copied + re-encoded into a clean temp folder for Object Capture.
    func runHighDetailReconstruction() {
        guard !isHighDetailReconstructing else { return }
        
        let fm = FileManager.default
        let captureFolder = imageWriter.sessionFolder(state: captureState)
        
        // 1. Collect all stills for this state.
        let allImages: [URL]
        do {
            let contents = try fm.contentsOfDirectory(
                at: captureFolder,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )
            allImages = contents.filter {
                ["jpg", "jpeg", "png", "heic", "heif"]
                    .contains($0.pathExtension.lowercased())
            }
        } catch {
            highDetailStatus = "Cannot read capture folder: \(error.localizedDescription)"
            statusText       = highDetailStatus
            return
        }
        
        guard !allImages.isEmpty else {
            highDetailStatus = "No photos found – capture first."
            statusText       = highDetailStatus
            return
        }
        
        // Sort chronologically for nicer sampling.
        let sortedImages: [URL] = allImages.sorted { lhs, rhs in
            let lDate = (try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate)
                ?? .distantPast
            let rDate = (try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate)
                ?? .distantPast
            if lDate != rDate { return lDate < rDate }
            return lhs.lastPathComponent < rhs.lastPathComponent
        }
        
        // 2. Pick a subset (avoid hundreds of very similar frames).
        let maxSamples = 140          // enough for high quality but not insane
        let sampled: [URL]
        if sortedImages.count <= maxSamples {
            sampled = sortedImages
        } else {
            let step = max(1, sortedImages.count / maxSamples)
            var tmp: [URL] = []
            for (idx, url) in sortedImages.enumerated() where idx % step == 0 {
                tmp.append(url)
                if tmp.count >= maxSamples { break }
            }
            sampled = tmp
        }
        
        // 3. Prepare a fresh input folder: /…/ObjectCapture/<state>/input
        let inputFolder = imageWriter.photogrammetryInputFolder(for: captureState)
        do {
            // Blow away any previous run completely.
            try? fm.removeItem(at: inputFolder)
            try fm.createDirectory(at: inputFolder, withIntermediateDirectories: true)
        } catch {
            highDetailStatus = "Cannot prepare input folder: \(error.localizedDescription)"
            statusText       = highDetailStatus
            return
        }
        
        // 4. Re-encode all selected images as JPEG into the input folder.
        var index = 0
        for src in sampled {
            autoreleasepool {
                guard
                    let img = UIImage(contentsOfFile: src.path),
                    let data = img.jpegData(compressionQuality: 0.96)
                else { return }
                
                let dstName = String(format: "img_%03d.jpg", index)
                let dstURL  = inputFolder.appendingPathComponent(dstName)
                try? data.write(to: dstURL, options: .atomic)
                index += 1
            }
        }
        
        guard index >= 20 else {
            highDetailStatus = "Not enough valid photos for reconstruction."
            statusText       = highDetailStatus
            return
        }
        
        let outputURL = inputFolder.appendingPathComponent("face_high_detail.usdz")
        try? fm.removeItem(at: outputURL)
        
        isHighDetailReconstructing = true
        highDetailStatus = "Photogrammetry: \(index) images – starting…"
        statusText = highDetailStatus
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            
            do {
                var config = PhotogrammetrySession.Configuration()
                config.isObjectMaskingEnabled = false
                config.sampleOrdering = .unordered
                config.featureSensitivity = .normal   // .high is touchier / more likely to fail
                
                let session = try PhotogrammetrySession(
                    input: inputFolder,
                    configuration: config
                )
                
                let request = PhotogrammetrySession.Request
                    .modelFile(url: outputURL, detail: .reduced)
                
                try session.process(requests: [request])
                
                for try await output in session.outputs {
                    switch output {
                    case .requestProgress(_, let fraction):
                        await MainActor.run {
                            let pct = Int(fraction * 100)
                            self.highDetailStatus = "Photogrammetry \(pct)%"
                            self.statusText       = self.highDetailStatus
                        }
                        
                    case .requestError(_, let error):
                        await MainActor.run {
                            self.handlePhotogrammetryError(error)
                        }
                        return
                        
                    case .requestComplete(_, let result):
                        if case .modelFile(let modelURL) = result {
                            do {
                                let scene = try SCNScene(url: modelURL, options: nil)
                                await MainActor.run {
                                    // Optional: trim back + add cap if you kept this helper.
                                    self.cleanupHighDetailScene(scene)
                                    
                                    self.previewScene        = scene
                                    self.previewGeometry     = nil
                                    self.highDetailModelURL  = modelURL
                                    self.isHighDetailReconstructing = false
                                    self.highDetailStatus    = "High-detail mesh ready"
                                    self.statusText          = self.highDetailStatus
                                }
                                return
                            } catch {
                                await MainActor.run {
                                    self.isHighDetailReconstructing = false
                                    self.highDetailStatus =
                                      "Photogrammetry OK, failed to load model."
                                    self.statusText = self.highDetailStatus
                                }
                                return
                            }
                        }
                        
                    case .processingComplete, .inputComplete:
                        // Nothing extra to do here.
                        break
                        
                    @unknown default:
                        break
                    }
                }
            } catch {
                await MainActor.run {
                    self.handlePhotogrammetryError(error)
                }
            }
        }
    }
    
    /// Centralised error handling so we always reset state.
    func handlePhotogrammetryError(_ error: Error) {
        isHighDetailReconstructing = false
        
        if let pError = error as? PhotogrammetrySession.Error {
            highDetailStatus = "Photogrammetry failed: \(pError)"
            print("PhotogrammetrySession error: \(pError)")
        } else {
            highDetailStatus = "Photogrammetry failed: \(error.localizedDescription)"
            print("Photogrammetry generic error: \(error)")
        }
        
        statusText = highDetailStatus
    }
}
