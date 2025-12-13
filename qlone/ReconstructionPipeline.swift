import Foundation
import SceneKit
import simd
import UIKit
import ModelIO
import SceneKit.ModelIO

/// Lightweight real-time geometry from ARKit point cloud for preview.
/// The watertight, textured model comes from Object Capture.
final class ReconstructionPipeline {
    
    func buildGeometry(from points: [SIMD3<Float>],
                       mode: PreviewMode,
                       textureImage: UIImage?) -> SCNGeometry {
        guard !points.isEmpty else {
            return SCNGeometry()
        }
        
        // Optional subsampling per mode (for performance)
        let usedPoints: [SIMD3<Float>]
        switch mode {
        case .pointCloud:
            usedPoints = points
        case .sparseMesh:
            // keep every 2nd point
            usedPoints = points.enumerated().compactMap { idx, p in
                idx % 2 == 0 ? p : nil
            }
        case .denseMesh:
            // keep all points
            usedPoints = points
        }
        
        // ---- Vertex buffer ----
        var vertexFloats = [Float]()
        vertexFloats.reserveCapacity(usedPoints.count * 3)
        for p in usedPoints {
            vertexFloats.append(p.x)
            vertexFloats.append(p.y)
            vertexFloats.append(p.z)
        }
        
        let vertexData: Data = vertexFloats.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
        
        let vertexSource = SCNGeometrySource(
            data: vertexData,
            semantic: .vertex,
            vectorCount: usedPoints.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float>.size * 3
        )
        
        // ---- Indices: one index per point ----
        var indices = [Int32]()
        indices.reserveCapacity(usedPoints.count)
        for i in 0..<usedPoints.count {
            indices.append(Int32(i))
        }
        
        let indexData: Data = indices.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
        
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .point,
            primitiveCount: usedPoints.count,
            bytesPerIndex: MemoryLayout<Int32>.size
        )
        
        let geometry = SCNGeometry(sources: [vertexSource], elements: [element])
        
        // ---- Material (color / texture) ----
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = textureImage ?? UIColor.systemBlue
        geometry.materials = [material]
        
        return geometry
    }
    
}
