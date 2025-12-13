// ARScanManager+Export.swift
import SceneKit
import ModelIO

extension ARScanManager {
    
    // MARK: - Export preview mesh
    
    func exportPreviewMesh(format: MeshExportFormat) -> URL? {
        var geometries: [SCNGeometry] = []
        
        if let g = previewGeometry {
            geometries.append(g)
        }
        if let scene = previewScene {
            collectGeometries(from: scene.rootNode, into: &geometries)
        }
        guard !geometries.isEmpty else {
            statusText = "No mesh in preview to export yet."
            return nil
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        
        let ext: String
        switch format {
        case .obj: ext = "obj"
        case .ply: ext = "ply"
        case .stl: ext = "stl"
        }
        
        let url = tempDir.appendingPathComponent("face_preview.\(ext)")
        
        let asset = MDLAsset()
        for g in geometries {
            let mdlMesh = MDLMesh(scnGeometry: g)
            asset.add(mdlMesh)
        }
        
        do {
            try asset.export(to: url)
            statusText = "Exported \(ext.uppercased())"
            return url
        } catch {
            statusText = "Export failed: \(error.localizedDescription)"
            return nil
        }
    }
    
    // MARK: - Geometry helpers
    
    func collectGeometries(from node: SCNNode, into array: inout [SCNGeometry]) {
        if let g = node.geometry {
            array.append(g)
        }
        for child in node.childNodes {
            collectGeometries(from: child, into: &array)
        }
    }
}

