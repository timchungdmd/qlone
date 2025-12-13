// MeshExporter.swift
import Foundation
import ModelIO
import SceneKit.ModelIO
import MetalKit

enum MeshExportError: Error {
    case noMeshFound
    case metalUnavailable
}

struct MeshExportService {
    
    /// Converts a USDZ model to another mesh format (OBJ, PLY, STL, …)
    /// based on the destination URL's file extension.
    static func export(usdzURL: URL, to destinationURL: URL) throws {
        // Ensure we have a Metal device for mesh buffer allocation
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            throw MeshExportError.metalUnavailable
        }
        
        let allocator = MTKMeshBufferAllocator(device: metalDevice)
        
        // Load the USDZ as a Model I/O asset
        let asset = MDLAsset(url: usdzURL,
                             vertexDescriptor: nil,
                             bufferAllocator: allocator)
        
        guard asset.count > 0 else {
            throw MeshExportError.noMeshFound
        }
        
        let firstObject = asset.object(at: 0)
        
        let exportAsset = MDLAsset()
        exportAsset.add(firstObject)
        
        let ext = destinationURL.pathExtension.lowercased()
        if !MDLAsset.canExportFileExtension(ext) {
            let fallbackURL = destinationURL.deletingPathExtension()
                .appendingPathExtension("obj")
            try exportAsset.export(to: fallbackURL)
            return
        }
        
        try exportAsset.export(to: destinationURL)
    }
}
