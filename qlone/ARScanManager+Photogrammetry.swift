import Foundation
import SceneKit
import RealityKit
import UIKit

extension ARScanManager {
    
    func runHighDetailReconstruction() {
        guard !isHighDetailReconstructing else { return }
        
        let fm = FileManager.default
        
        Task {
            let captureFolder = await imageWriter.sessionFolder(state: captureState)
            
            // 1. Find JPEGs
            let allImages = (try? fm.contentsOfDirectory(at: captureFolder, includingPropertiesForKeys: nil))?
                .filter { $0.pathExtension.lowercased() == "jpg" } ?? []
            
            // Need at least 20 images
            guard allImages.count >= 20 else {
                await MainActor.run {
                    self.highDetailStatus = "Need more photos (20+)"
                    self.statusText = self.highDetailStatus
                }
                return
            }
            
            // 2. Prepare Input Folder
            let inputFolder = await imageWriter.photogrammetryInputFolder(for: captureState)
            try? fm.removeItem(at: inputFolder)
            try? fm.createDirectory(at: inputFolder, withIntermediateDirectories: true)
            
            await MainActor.run {
                self.isHighDetailReconstructing = true
                self.highDetailStatus = "Preparing data..."
                self.statusText = self.highDetailStatus
            }
            
            // 3. Copy Images (Sanitize names for safety)
            // Sort by filename (timestamp)
            let sorted = allImages.sorted { $0.lastPathComponent < $1.lastPathComponent }
            
            // Limit to 150 to prevent memory crashes
            let maxCount = 150
            let selection = sorted.count > maxCount ? Array(sorted.prefix(maxCount)) : sorted
            
            for (i, url) in selection.enumerated() {
                let dest = inputFolder.appendingPathComponent("img_\(String(format: "%04d", i)).jpg")
                try? fm.copyItem(at: url, to: dest)
            }
            
            // 4. Run Session
            let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let outputURL = docs.appendingPathComponent("final_model.usdz")
            try? fm.removeItem(at: outputURL)
            
            await MainActor.run {
                self.highDetailStatus = "Processing \(selection.count) images..."
            }
            
            do {
                var config = PhotogrammetrySession.Configuration()
                config.isObjectMaskingEnabled = false
                config.sampleOrdering = .unordered
                config.featureSensitivity = .normal
                
                let session = try PhotogrammetrySession(input: inputFolder, configuration: config)
                
                // FIX: Use .reduced instead of .preview for compatibility
                let request = PhotogrammetrySession.Request.modelFile(url: outputURL, detail: .reduced)
                
                try session.process(requests: [request])
                
                for try await output in session.outputs {
                    switch output {
                    case .requestProgress(_, let fraction):
                        await MainActor.run {
                            self.highDetailStatus = "Building: \(Int(fraction * 100))%"
                        }
                    case .requestComplete(_, let result):
                        if case .modelFile(let url) = result {
                            await MainActor.run {
                                do {
                                    let scene = try SCNScene(url: url, options: nil)
                                    // Use your cleanup logic
                                    self.cleanupHighDetailScene(scene)
                                    self.highDetailModelURL = url
                                    self.highDetailStatus = "Done!"
                                    self.isHighDetailReconstructing = false
                                    self.previewScene = scene
                                } catch {
                                    print("Load error: \(error)")
                                }
                            }
                        }
                    case .requestError(_, let error):
                        print("PG Error: \(error)")
                    default: break
                    }
                }
            } catch {
                await MainActor.run {
                    self.isHighDetailReconstructing = false
                    self.highDetailStatus = "Failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
