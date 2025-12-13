// ARScanManager+HighDetailCleanup.swift
import Foundation
import SceneKit
import UIKit

extension ARScanManager {
    
    /// Remove far-away “islands” from the mesh and add a flat back cap.
    func cleanupHighDetailScene(_ scene: SCNScene) {
        let root = scene.rootNode
        let (minB, maxB) = root.boundingBox
        
        // Bounding box center and radius
        let center = SCNVector3(
            (minB.x + maxB.x) * 0.5,
            (minB.y + maxB.y) * 0.5,
            (minB.z + maxB.z) * 0.5
        )
        let extentX = maxB.x - minB.x
        let extentY = maxB.y - minB.y
        let extentZ = maxB.z - minB.z
        let maxExtent = max(extentX, max(extentY, extentZ))
        let maxRadius: Float = maxExtent * 0.75
        
        removeOutliers(from: root, center: center, maxRadius: maxRadius)
        addBackCap(to: root)
    }
    
    /// Recursively delete child nodes whose centers are far from the model center.
    private func removeOutliers(from node: SCNNode,
                                center: SCNVector3,
                                maxRadius: Float) {
        for child in node.childNodes {
            var removed = false
            if child.geometry != nil {
                let (minB, maxB) = child.boundingBox
                let cx = (minB.x + maxB.x) * 0.5
                let cy = (minB.y + maxB.y) * 0.5
                let cz = (minB.z + maxB.z) * 0.5
                let dx = cx - center.x
                let dy = cy - center.y
                let dz = cz - center.z
                let r2 = dx*dx + dy*dy + dz*dz
                if r2 > maxRadius * maxRadius {
                    child.removeFromParentNode()
                    removed = true
                }
            }
            if !removed {
                removeOutliers(from: child, center: center, maxRadius: maxRadius)
            }
        }
    }
    
    /// Simple flat “back cap” so the head is closed posteriorly.
    private func addBackCap(to root: SCNNode) {
        let (minB, maxB) = root.boundingBox
        let width  = CGFloat(maxB.x - minB.x) * 1.05
        let height = CGFloat(maxB.y - minB.y) * 1.05
        
        guard width > 0, height > 0 else { return }
        
        let plane = SCNPlane(width: width, height: height)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemGray
        material.isDoubleSided = false
        plane.materials = [material]
        
        let planeNode = SCNNode(geometry: plane)
        planeNode.position = SCNVector3(
            (minB.x + maxB.x) * 0.5,
            (minB.y + maxB.y) * 0.5,
            minB.z - 0.002   // slightly behind
        )
        
        // Flip to face forward
        planeNode.eulerAngles = SCNVector3(Float.pi, 0, 0)
        root.addChildNode(planeNode)
    }
}
