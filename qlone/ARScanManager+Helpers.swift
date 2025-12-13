// ARScanManager+Helpers.swift
import ARKit
import UIKit
import CoreImage

extension ARScanManager {
    
    // MARK: - Coordinate helpers
    
    func transformToReferenceSpace(_ point: SIMD3<Float>) -> SIMD3<Float> {
        guard let inv = referenceCameraInverse else { return point }
        let p4 = SIMD4<Float>(point.x, point.y, point.z, 1.0)
        let local = inv * p4
        return SIMD3<Float>(local.x, local.y, local.z)
    }
    
    func projectToImagePoint(worldPoint: SIMD3<Float>,
                             frame: ARFrame,
                             imageSize: CGSize) -> CGPoint? {
        let p = simd_float3(worldPoint.x, worldPoint.y, worldPoint.z)
        return frame.camera.projectPoint(
            p,
            orientation: .portrait,
            viewportSize: imageSize
        )
    }
    
    func expandedRect(_ rect: CGRect, factor: CGFloat) -> CGRect {
        var r = rect.insetBy(
            dx: -rect.width * (factor - 1) * 0.5,
            dy: -rect.height * (factor - 1) * 0.5
        )
        r.origin.x = max(0, r.origin.x)
        r.origin.y = max(0, r.origin.y)
        r.size.width = min(1.0 - r.origin.x, r.size.width)
        r.size.height = min(1.0 - r.origin.y, r.size.height)
        return r
    }
    
    func headRect(fromFaceRect face: CGRect, imageSize: CGSize) -> CGRect {
        var rect = face
        
        let topExtra = face.height * 0.6
        rect.origin.y = max(0, face.origin.y - topExtra)
        rect.size.height = face.height + topExtra
        
        let bottomExtra = face.height * 0.25
        if rect.origin.y + rect.size.height + bottomExtra <= imageSize.height {
            rect.size.height += bottomExtra
        } else {
            rect.size.height = imageSize.height - rect.origin.y
        }
        
        let sideExtra = face.width * 0.25
        rect.origin.x = max(0, rect.origin.x - sideExtra)
        if rect.origin.x + rect.size.width + 2 * sideExtra <= imageSize.width {
            rect.size.width += 2 * sideExtra
        } else {
            rect.size.width = imageSize.width - rect.origin.x
        }
        
        return rect
    }
    
    func crop(image: UIImage, to rect: CGRect) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let scale = image.scale
        
        let scaledRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.size.width * scale,
            height: rect.size.height * scale
        ).integral
        
        guard let cropped = cg.cropping(to: scaledRect) else { return image }
        return UIImage(cgImage: cropped,
                       scale: scale,
                       orientation: image.imageOrientation)
    }
    
    // MARK: - Image conversion
    
    static func image(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
    }
}
