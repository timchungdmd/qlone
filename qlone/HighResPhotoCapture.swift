import AVFoundation
import UIKit

final class HighResPhotoCapture: NSObject, AVCapturePhotoCaptureDelegate {

    static let shared = HighResPhotoCapture()

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var completion: ((UIImage?) -> Void)?

    private override init() {
        super.init()
        configureSession()
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                 for: .video,
                                                 position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)

        guard session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            return
        }

        session.addOutput(photoOutput)
        photoOutput.isHighResolutionCaptureEnabled = true

        session.commitConfiguration()
    }

    func startIfNeeded() {
        if !session.isRunning {
            session.startRunning()
        }
    }

    func stopIfIdle() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    // --------------------------------------------------------------------
    // 1) “Normal” high-res capture (kept for backwards compatibility)
    // --------------------------------------------------------------------
    func capture(completion: @escaping (UIImage?) -> Void) {
        startIfNeeded()
        self.completion = completion

        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // --------------------------------------------------------------------
    // 2) Fast-shutter capture with high ISO (for macro / motion control)
    // --------------------------------------------------------------------
    func captureFast(
        iso: Float = 1200,
        minShutter: CMTime = CMTimeMake(value: 1, timescale: 500), // 1/500s
        completion: @escaping (UIImage?) -> Void
    ) {
        startIfNeeded()
        self.completion = completion

        // Configure exposure on the video device
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .back)
        else {
            // No device; just fall back to normal capture
            capture(completion: completion)
            return
        }

        do {
            try device.lockForConfiguration()

            let clampedISO = max(device.activeFormat.minISO,
                                 min(iso, device.activeFormat.maxISO))

            let minDuration = device.activeFormat.minExposureDuration
            let maxDuration = device.activeFormat.maxExposureDuration

            // We don’t want anything *longer* than minShutter, but never shorter
            let desired = CMTimeMaximum(minDuration, minShutter)
            let duration = CMTimeMinimum(desired, maxDuration)

            if device.isExposureModeSupported(.custom) {
                device.setExposureModeCustom(
                    duration: duration,
                    iso: clampedISO,
                    completionHandler: nil
                )
            } else {
                device.exposureMode = .continuousAutoExposure
            }

            device.unlockForConfiguration()
        } catch {
            // If exposure lock fails, just continue with auto exposure
        }

        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - AVCapturePhotoCaptureDelegate

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard
            error == nil,
            let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data)
        else {
            completion?(nil)
            completion = nil
            return
        }

        completion?(image)
        completion = nil
    }
}
