import Foundation

extension ARScanManager {
    /// Cancel any running high-detail job and delete its input images.
    func cancelHighDetailAndDeleteImages() {
        isHighDetailReconstructing = false
        highDetailStatus = "Photogrammetry cancelled"
        statusText = highDetailStatus
        
        // Drop the input photos so a rerun starts fresh
        let folder = imageWriter.photogrammetryInputFolder(for: captureState)
        try? FileManager.default.removeItem(at: folder)
    }
    
    /// Delete current high-detail model + capture images.
    func deleteHighDetailAndCaptures() {
        if let url = highDetailModelURL {
            try? FileManager.default.removeItem(at: url)
        }
        highDetailModelURL = nil
        highDetailStatus = "Mesh deleted"
        statusText = highDetailStatus
        
        // Clear both photogrammetry input and still captures
        let capFolder = imageWriter.sessionFolder(state: captureState)
        try? FileManager.default.removeItem(at: capFolder)
        
        let inputFolder = imageWriter.photogrammetryInputFolder(for: captureState)
        try? FileManager.default.removeItem(at: inputFolder)
        
        previewScene = nil
        previewGeometry = nil
    }
   

}
