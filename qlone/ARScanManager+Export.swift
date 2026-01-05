// FILE: qlone/ARScanManager+Export.swift
import Foundation
import SceneKit
import ModelIO
import SceneKit.ModelIO

// MARK: - Export Extension

extension ARScanManager {
    
    /// Prepare raw images for AirDrop
    func prepareRawDataForExport() async -> URL? {
        let fileManager = FileManager.default
        let sourceURL = await imageWriter.sessionFolder(state: captureState)
        
        // Validation
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDir), isDir.boolValue else {
            statusText = "Export Error: Source missing."
            return nil
        }
        
        // Staging
        let tempDir = fileManager.temporaryDirectory
        let targetName = "DentalScan_\(captureState.rawValue.capitalized)_Data"
        let targetURL = tempDir.appendingPathComponent(targetName)
        
        try? fileManager.removeItem(at: targetURL)
        
        do {
            try fileManager.copyItem(at: sourceURL, to: targetURL)
            statusText = "Ready to Share"
            return targetURL
        } catch {
            statusText = "Export Failed: \(error.localizedDescription)"
            return nil
        }
    }
    
    /// Export mesh to STL/OBJ
    func exportPreviewMesh(format: MeshExportFormat) -> URL? {
        guard let scene = previewScene else {
            statusText = "No mesh to export."
            return nil
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "dental_scan_ios_proxy"
        let url = tempDir.appendingPathComponent("\(fileName).\(format.fileExtension)")
        let asset = MDLAsset()
        
        scene.rootNode.enumerateChildNodes { node, _ in
            if let geometry = node.geometry {
                let mdlMesh = MDLMesh(scnGeometry: geometry)
                if format == .stl {
                    let scale: Float = 1000.0 // mm
                    let transform = matrix_float4x4(diagonal: SIMD4<Float>(scale, scale, scale, 1))
                    mdlMesh.transform = MDLTransform(matrix: transform)
                }
                asset.add(mdlMesh)
            }
        }
        
        if asset.count == 0 { return nil }
        
        do {
            try asset.export(to: url)
            return url
        } catch {
            statusText = "Export failed."
            return nil
        }
    }
}
