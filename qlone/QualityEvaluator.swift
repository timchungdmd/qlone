import UIKit

/// Placeholder image quality evaluator.
/// You can later plug in blur/SNR or ML-based scoring.
final class QualityEvaluator {
    func score(image: UIImage, mouthROI: CGRect?) -> Float {
        0.8
    }
    
    func mouthSpecificScore(image: UIImage, mouthROI: CGRect?) -> Float {
        0.8
    }
}
