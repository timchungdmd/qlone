// ARScanManager+Preview.swift
import SceneKit
import UIKit

extension ARScanManager {
    
    // MARK: - Preview / commit
    
    func buildPreviewForCurrentState() {
        updatePreviewGeometry()
        statusText = "Preview updated"
    }
    
    func commitState() {
        statusText = "State \(captureState.rawValue) images saved (\(frameCountForState) frames)"
    }
    
    // MARK: - Preview geometry
    
    func updatePreviewGeometry() {
        let facePts = facePointsByState[captureState] ?? []
        let rawPts  = rawPointsByState[captureState] ?? []
        
        let points: [SIMD3<Float>]
        if !facePts.isEmpty {
            points = facePts + rawPts
        } else {
            points = rawPts
        }
        
        guard !points.isEmpty else { return }
        
        let geometry = reconstruction.buildGeometry(
            from: points,
            mode: previewMode,
            textureImage: lastTextureImage
        )
        previewGeometry = geometry
        
        let scene: SCNScene
        if let s = previewScene {
            scene = s
        } else {
            let s = SCNScene()
            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.position = SCNVector3(0, 0, 0.5)
            s.rootNode.addChildNode(cameraNode)
            previewScene = s
            scene = s
        }
        
        if let existing = scene.rootNode.childNodes.first(where: { $0.geometry != nil }) {
            existing.geometry = geometry
        } else {
            let node = SCNNode(geometry: geometry)
            scene.rootNode.addChildNode(node)
        }
        
        previewScene = scene
    }
}
