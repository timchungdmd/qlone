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
            
            // 1. Find JPEG images (Fixes read errors)
            let allFiles = (try? fm.contentsOfDirectory(at: captureFolder, includingPropertiesForKeys: nil)) ?? []
            let imageFiles = allFiles.filter { $0.pathExtension.lowercased() == "jpeg" || $0.pathExtension.lowercased() == "jpg" }
            
            guard imageFiles.count >= 10 else {
                await MainActor.run {
                    self.highDetailStatus = "Need more photos (10+)"
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
            
            // 3. Copy Images
            let sortedImages = imageFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }
            let maxCount = 150
            let selection = sortedImages.count > maxCount ? Array(sortedImages.prefix(maxCount)) : sortedImages
            
            for (i, url) in selection.enumerated() {
                let newBaseName = "img_\(String(format: "%04d", i))"
                let destImage = inputFolder.appendingPathComponent("\(newBaseName).jpeg")
                try? fm.copyItem(at: url, to: destImage)
            }
            
            // 4. Run Photogrammetry
            let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let outputURL = docs.appendingPathComponent("final_model.usdz")
            try? fm.removeItem(at: outputURL)
            
            await MainActor.run {
                self.highDetailStatus = "Processing \(selection.count) images..."
            }
            
            do {
                var config = PhotogrammetrySession.Configuration()
                config.isObjectMaskingEnabled = true // Masking ON (using images only for on-device stability)
                config.sampleOrdering = .unordered
                config.featureSensitivity = .high
                
                let session = try PhotogrammetrySession(input: inputFolder, configuration: config)
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
                        await MainActor.run {
                            self.highDetailStatus = "Error: \(error.localizedDescription)"
                        }
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
