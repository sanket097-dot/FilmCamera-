import Foundation
import AVFoundation
import UIKit
import CoreImage

struct CameraCapture {
    let rawData: Data?
    let processedData: Data?
}

final class CameraService: NSObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "film.camera.session")
    private let videoQueue = DispatchQueue(label: "film.camera.video", qos: .userInitiated)
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false, .cacheIntermediates: true])
    private let renderer = FilmRenderer()
    private var activeDevice: AVCaptureDevice?
    private var photoDelegate: PhotoCaptureDelegate?
    private var currentLook = FilmLook.portra400
    private var grainStrength: Float = 0.12
    private var frameNumber = 0
    private var configured = false

    var onStateChange: ((Bool, Bool, String) -> Void)?
    var onCapture: ((Result<CameraCapture, Error>) -> Void)?
    var onVideoFrame: ((UIImage) -> Void)?

    func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
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
                if !self.configured {
                    self.session.beginConfiguration()
                    self.session.sessionPreset = .photo
                    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                               for: .video,
                                                               position: .back) else {
                        throw CameraError.noCamera
                    }
                    self.activeDevice = device
                    let input = try AVCaptureDeviceInput(device: device)
                    guard self.session.canAddInput(input) else { throw CameraError.setupFailed }
                    self.session.addInput(input)

                    guard self.session.canAddOutput(self.photoOutput) else { throw CameraError.setupFailed }
                    self.session.addOutput(self.photoOutput)
                    self.photoOutput.maxPhotoQualityPrioritization = .quality
                    if self.photoOutput.isAppleProRAWSupported {
                        self.photoOutput.isAppleProRAWEnabled = true
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
                    self.session.commitConfiguration()
                    self.configured = true
                }

                self.session.startRunning()
                let rawAvailable = !self.photoOutput.availableRawPhotoPixelFormatTypes.isEmpty
                let hasProRAW = self.photoOutput.availableRawPhotoPixelFormatTypes.contains {
                    AVCapturePhotoOutput.isAppleProRAWPixelFormat($0)
                }
                let detail = hasProRAW ? "Apple ProRAW + JPEG ready" :
                    (rawAvailable ? "Bayer RAW + JPEG ready" : "Processed JPEG capture")
                self.onStateChange?(true, rawAvailable, "Live film preview · \(detail)")
            } catch {
                if self.session.isRunning { self.session.stopRunning() }
                if self.session.isInterrupted == false {
                    // Configuration errors are reported without leaving the UI in a false-ready state.
                }
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
                let value = max(device.minExposureTargetBias, min(device.maxExposureTargetBias, bias))
                device.setExposureTargetBias(value)
                device.unlockForConfiguration()
            } catch { }
        }
    }

    func setFocusAndExposure(point: CGPoint) {
        sessionQueue.async {
            guard let device = self.activeDevice else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = CGPoint(x: point.y, y: 1 - point.x)
                    if device.isFocusModeSupported(.autoFocus) { device.focusMode = .autoFocus }
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = CGPoint(x: point.x, y: 1 - point.y)
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                }
                device.unlockForConfiguration()
            } catch { }
        }
    }

    func setFocusLocked(_ locked: Bool) {
        sessionQueue.async {
            guard let device = self.activeDevice else { return }
            do {
                try device.lockForConfiguration()
                if locked {
                    if device.isFocusModeSupported(.locked) { device.focusMode = .locked }
                    if device.isExposureModeSupported(.locked) { device.exposureMode = .locked }
                } else {
                    if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
                    if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
                }
                device.unlockForConfiguration()
            } catch { }
        }
    }

    func setManualFocus(_ position: Float) {
        sessionQueue.async {
            guard let device = self.activeDevice,
                  device.isLockingFocusWithCustomLensPositionSupported else { return }
            do {
                try device.lockForConfiguration()
                device.setFocusModeLocked(lensPosition: max(0, min(1, position)))
                device.unlockForConfiguration()
            } catch { }
        }
    }

    func capture(raw: Bool, flash: AVCaptureDevice.FlashMode) {
        sessionQueue.async {
            let settings: AVCapturePhotoSettings
            if raw, let rawType = self.photoOutput.availableRawPhotoPixelFormatTypes.first {
                let processed: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.jpeg]
                settings = AVCapturePhotoSettings(rawPixelFormatType: rawType,
                                                   processedFormat: processed)
            } else {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            }
            settings.photoQualityPrioritization = .quality
            if self.photoOutput.supportedFlashModes.contains(flash) {
                settings.flashMode = flash
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
            let fullFrame = CIImage(cvPixelBuffer: pixelBuffer)
            let scale = min(1.0, 1280.0 / max(fullFrame.extent.width, fullFrame.extent.height))
            let source = scale < 1
                ? fullFrame.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                : fullFrame
            let processed = renderer.applying(currentLook, to: source, grain: grainStrength)
            guard let cgImage = ciContext.createCGImage(processed, from: processed.extent) else { return }
            let frame = UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
            DispatchQueue.main.async { [weak self] in self?.onVideoFrame?(frame) }
        }
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<CameraCapture, Error>) -> Void
    private var rawData: Data?
    private var processedData: Data?
    private var finished = false

    init(completion: @escaping (Result<CameraCapture, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if error != nil { return }
        guard let data = photo.fileDataRepresentation() else { return }
        if photo.isRawPhoto { rawData = data } else { processedData = data }
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
        guard !finished else { return }
        finished = true
        if let error {
            completion(.failure(error))
        } else if rawData != nil || processedData != nil {
            completion(.success(CameraCapture(rawData: rawData, processedData: processedData)))
        } else {
            completion(.failure(CameraCaptureError.noImageData))
        }
    }

    private enum CameraCaptureError: LocalizedError {
        case noImageData
        var errorDescription: String? { "The camera returned no image data." }
    }
}

private enum CameraError: LocalizedError {
    case noCamera
    case setupFailed
    var errorDescription: String? {
        switch self {
        case .noCamera: return "No compatible rear camera was found."
        case .setupFailed: return "The camera session could not be configured."
        }
    }
}
