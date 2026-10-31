import Foundation
import AVFoundation
import UIKit
import CoreImage

final class CameraService: NSObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "film.camera.session")
    private let videoQueue = DispatchQueue(label: "film.camera.video", qos: .userInitiated)
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let renderer = FilmRenderer()
    private var activeDevice: AVCaptureDevice?
    private var photoDelegate: PhotoCaptureDelegate?
    private var currentLook = FilmLook.portra400
    private var grainStrength: Float = 0.12
    private var frameNumber = 0

    var onStateChange: ((Bool, Bool, String) -> Void)?
    var onCapture: ((Result<Data, Error>) -> Void)?
    var onVideoFrame: ((UIImage) -> Void)?

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

    func setFilmLook(_ look: FilmLook, grain: Float) {
        sessionQueue.async {
            self.currentLook = look
            self.grainStrength = grain
        }
    }

    func configureAndStart() {
        sessionQueue.async {
            guard !self.session.isRunning else { return }
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
                if self.session.canAddOutput(self.videoOutput) {
                    self.videoOutput.videoSettings = [
                        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                    ]
                    self.videoOutput.alwaysDiscardsLateVideoFrames = true
                    self.session.addOutput(self.videoOutput)
                    self.videoOutput.setSampleBufferDelegate(self, queue: self.videoQueue)
                    self.videoOutput.connection(with: .video)?.videoOrientation = .portrait
                }

                self.photoOutput.maxPhotoQualityPrioritization = .quality
                self.session.commitConfiguration()
                self.session.startRunning()

                let rawAvailable = !self.photoOutput.availableRawPhotoPixelFormatTypes.isEmpty
                self.onStateChange?(true, rawAvailable,
                                    rawAvailable
                                    ? "Live film preview · RAW capture available"
                                    : "Live film preview · Processed capture")
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
                if self.photoOutput.supportedFlashModes.contains(flash) {
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
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        frameNumber += 1
        guard frameNumber % 2 == 0,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        autoreleasepool {
            let source = CIImage(cvPixelBuffer: pixelBuffer)
            let processed = renderer.applying(currentLook, to: source, grain: grainStrength)
            guard let cgImage = ciContext.createCGImage(processed, from: processed.extent) else { return }
            let frame = UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
            DispatchQueue.main.async { [weak self] in
                self?.onVideoFrame?(frame)
            }
        }
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

private enum CameraError: LocalizedError {
    case noCamera
    var errorDescription: String? { "No compatible rear camera was found." }
}
