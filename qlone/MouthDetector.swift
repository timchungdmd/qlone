import UIKit
import Vision

/// Runs on-device Vision to detect a face, mouth ROI, and dense
/// landmark keypoints (eyes, nose, lips, contour).
///
/// ARScanManager uses `lastKeypoints` to bias the AR feature-point
/// sampling toward clinically important regions.
final class MouthDetector {
    
    // 2D keypoints in image coordinates (pixels, UIKit space)
    private(set) var lastKeypoints: [CGPoint] = []
    
    func detectFaceAndMouth(in image: UIImage) -> FaceAndMouthDetection? {
        lastKeypoints = []
        guard let cgImage = image.cgImage else { return nil }
        
        // Orientation: match how `ARScanManager.image(from:)` orients the UIImage.
        // We used `.right` there (landscape camera rotated to portrait),
        // so pass `.right` here as well.
        let orientation: CGImagePropertyOrientation = .right
        
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: orientation,
            options: [:]
        )
        
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        
        guard let face = request.results?.first as? VNFaceObservation else {
            return nil
        }
        
        let imageSize = image.size
        
        // Face bounding box in UIKit pixel coords
        let faceRect = convert(rect: face.boundingBox, in: imageSize)
        
        // Build landmark keypoints (eyes, nose, lips, contour)
        var keypoints: [CGPoint] = []
        
        if let leftEye = face.landmarks?.leftEye {
            keypoints.append(contentsOf: convert(region: leftEye,
                                                 in: face.boundingBox,
                                                 imageSize: imageSize))
        }
        
        if let rightEye = face.landmarks?.rightEye {
            keypoints.append(contentsOf: convert(region: rightEye,
                                                 in: face.boundingBox,
                                                 imageSize: imageSize))
        }
        
        if let nose = face.landmarks?.nose {
            keypoints.append(contentsOf: convert(region: nose,
                                                 in: face.boundingBox,
                                                 imageSize: imageSize))
        }
        
        if let noseCrest = face.landmarks?.noseCrest {
            keypoints.append(contentsOf: convert(region: noseCrest,
                                                 in: face.boundingBox,
                                                 imageSize: imageSize))
        }
        
        if let outerLips = face.landmarks?.outerLips {
            keypoints.append(contentsOf: convert(region: outerLips,
                                                 in: face.boundingBox,
                                                 imageSize: imageSize))
        }
        
        if let innerLips = face.landmarks?.innerLips {
            keypoints.append(contentsOf: convert(region: innerLips,
                                                 in: face.boundingBox,
                                                 imageSize: imageSize))
        }
        
        if let contour = face.landmarks?.faceContour {
            keypoints.append(contentsOf: convert(region: contour,
                                                 in: face.boundingBox,
                                                 imageSize: imageSize))
        }
        
        lastKeypoints = keypoints
        
        // Derive a mouth ROI from the outer or inner lips
        var mouthRect = faceRect
        if let outerLips = face.landmarks?.outerLips {
            let pts = convert(region: outerLips,
                              in: face.boundingBox,
                              imageSize: imageSize)
            if let bounds = boundingRect(of: pts) {
                mouthRect = bounds
            }
        } else if let innerLips = face.landmarks?.innerLips {
            let pts = convert(region: innerLips,
                              in: face.boundingBox,
                              imageSize: imageSize)
            if let bounds = boundingRect(of: pts) {
                mouthRect = bounds
            }
        }
        
        return FaceAndMouthDetection(
            faceBoundingBox: faceRect,
            mouthROI: mouthRect,
            confidence: face.confidence
        )
    }
    
    // MARK: - Coordinate helpers
    
    /// Convert Vision's normalized bounding box to UIKit pixel coordinates.
    private func convert(rect: CGRect, in imageSize: CGSize) -> CGRect {
        // Vision: origin at bottom-left in normalized coordinates.
        var r = rect
        r.origin.y = 1.0 - r.origin.y - r.size.height
        
        return CGRect(
            x: r.origin.x * imageSize.width,
            y: r.origin.y * imageSize.height,
            width: r.size.width * imageSize.width,
            height: r.size.height * imageSize.height
        )
    }
    
    /// Convert a landmark region (normalized within the bounding box)
    /// to UIKit pixel coordinates.
    private func convert(region: VNFaceLandmarkRegion2D,
                         in boundingBox: CGRect,
                         imageSize: CGSize) -> [CGPoint] {
        let points = region.normalizedPoints
        var result: [CGPoint] = []
        result.reserveCapacity(points.count)
        
        for p in points {
            // Normalized within bounding box
            let xNorm = boundingBox.origin.x + CGFloat(p.x) * boundingBox.width
            let yNorm = boundingBox.origin.y + CGFloat(p.y) * boundingBox.height
            
            // Flip to UIKit space (Vision origin: bottom-left)
            var pt = CGPoint(x: xNorm, y: yNorm)
            pt.y = 1.0 - pt.y
            
            // Scale to pixels
            pt.x *= imageSize.width
            pt.y *= imageSize.height
            result.append(pt)
        }
        
        return result
    }
    
    private func boundingRect(of points: [CGPoint]) -> CGRect? {
        guard let first = points.first else { return nil }
        var minX = first.x, maxX = first.x
        var minY = first.y, maxY = first.y
        
        for p in points.dropFirst() {
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
        }
        
        return CGRect(x: minX,
                      y: minY,
                      width: maxX - minX,
                      height: maxY - minY)
    }
}
