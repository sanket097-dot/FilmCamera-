import Foundation
import AVFoundation

final class CameraService: NSObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "film.camera.session")
    private var activeDevice: AVCaptureDevice?
    private var photoDelegate: PhotoCaptureDelegate?

    var onStateChange: ((Bool, Bool, String) -> Void)?
    var onCapture: ((Result<Data, Error>) -> Void)?

    func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    func configureAndStart() {
        sessionQueue.async {
            do {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo

                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                           for: .video,
                                                           position: .back) else {
                    throw CameraError.noCamera
                }
                self.activeDevice = device

                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) { self.session.addInput(input) }

                if self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                }

                self.photoOutput.maxPhotoQualityPrioritization = .quality
                self.session.commitConfiguration()
                self.session.startRunning()

                let rawAvailable = !self.photoOutput.availableRawPhotoPixelFormatTypes.isEmpty
                self.onStateChange?(true, rawAvailable,
                                    rawAvailable
                                    ? "Camera ready · RAW supported"
                                    : "Camera ready · RAW not exposed on this configuration")
            } catch {
                self.session.commitConfiguration()
                self.onStateChange?(false, false, error.localizedDescription)
            }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func setExposureBias(_ bias: Float) {
        sessionQueue.async {
            guard let device = self.activeDevice else { return }
            do {
                try device.lockForConfiguration()
                let clamped = max(device.minExposureTargetBias,
                                  min(device.maxExposureTargetBias, bias))
                device.setExposureTargetBias(clamped)
                device.unlockForConfiguration()
            } catch { }
        }
    }

    func capture(raw: Bool, flash: AVCaptureDevice.FlashMode) {
        sessionQueue.async {
            let settings: AVCapturePhotoSettings

            if raw,
               let rawType = self.photoOutput.availableRawPhotoPixelFormatTypes.first {
                settings = AVCapturePhotoSettings(rawPixelFormatType: rawType,
                                                  processedFormat: nil)
            } else {
                settings = AVCapturePhotoSettings()
                settings.photoQualityPrioritization = .quality
                if self.photoOutput.supportedFlashModes.contains(NSNumber(value: flash.rawValue)) {
                    settings.flashMode = flash
                }
            }

            let delegate = PhotoCaptureDelegate { [weak self] result in
                self?.onCapture?(result)
                self?.sessionQueue.async { self?.photoDelegate = nil }
            }
            self.photoDelegate = delegate
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    enum CameraError: LocalizedError {
        case noCamera
        var errorDescription: String? { "No compatible rear camera was found." }
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<Data, Error>) -> Void

    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error {
            completion(.failure(error))
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            completion(.failure(CaptureError.noImageData))
            return
        }
        completion(.success(data))
    }

    enum CaptureError: LocalizedError {
        case noImageData
        var errorDescription: String? { "The camera returned no image data." }
    }
}
