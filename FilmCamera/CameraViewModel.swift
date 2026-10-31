import Foundation
import SwiftUI
import AVFoundation
import Photos
import UIKit
import CoreImage
import UniformTypeIdentifiers
import ImageIO

enum ViewfinderAspectRatio: String, CaseIterable, Identifiable {
    case ratio4x3 = "4:3"
    case ratio3x2 = "3:2"
    case ratio16x9 = "16:9"
    case square = "1:1"
    var id: String { rawValue }
    var value: CGFloat {
        switch self {
        case .ratio4x3: return 4.0 / 3.0
        case .ratio3x2: return 3.0 / 2.0
        case .ratio16x9: return 16.0 / 9.0
        case .square: return 1
        }
    }
}

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var authorizationGranted = false
    @Published var cameraReady = false
    @Published var statusMessage = "Preparing camera…"
    @Published var selectedLook: FilmLook = .portra400 { didSet { updatePreviewLook() } }
    @Published var captureRAW = true
    @Published var rawAvailable = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var exposureBias: Float = 0
    @Published var isCapturing = false
    @Published var latestImage: UIImage?
    @Published var previewImage: UIImage?
    @Published var showSettings = false
    @Published var grainStrength: Float = 0.12 { didSet { updatePreviewLook() } }
    @Published var bloomStrength: Float = 0.10 { didSet { updatePreviewLook() } }
    @Published var vignetteStrength: Float = 0.18 { didSet { updatePreviewLook() } }
    @Published var selectedAspectRatio: ViewfinderAspectRatio = .ratio4x3
    @Published var showGrid = false

    @Published var manualExposure = false {
        didSet { applyManualExposure() }
    }
    @Published var isoValue: Float = 100 {
        didSet { if manualExposure { applyManualExposure() } }
    }
    @Published var shutterSeconds: Double = 1.0 / 125.0 {
        didSet { if manualExposure { applyManualExposure() } }
    }
    @Published var manualFocus = false {
        didSet { cameraService.setManualFocus(focusPosition, enabled: manualFocus) }
    }
    @Published var focusPosition: Float = 0.5 {
        didSet { if manualFocus { cameraService.setManualFocus(focusPosition, enabled: true) } }
    }

    @Published var timerSeconds = 0
    @Published var rollLength = 36
    @Published private(set) var framesShot = UserDefaults.standard.integer(forKey: "filmRollFramesShot")
    @Published var showRollFullAlert = false

    let cameraService = CameraService()
    private let renderer = FilmRenderer()
    private var captureTask: Task<Void, Never>?

    var framesRemaining: Int { max(0, rollLength - framesShot) }
    var rollIsFull: Bool { framesRemaining == 0 }

    init() {
        cameraService.onStateChange = { [weak self] ready, raw, message in
            Task { @MainActor in
                self?.cameraReady = ready
                self?.rawAvailable = raw
                self?.captureRAW = raw
                self?.statusMessage = message
            }
        }
        cameraService.onVideoFrame = { [weak self] image in
            Task { @MainActor in self?.previewImage = image }
        }
        cameraService.onCapture = { [weak self] result in
            Task { @MainActor in await self?.processCapture(result) }
        }
    }

    func start() async {
        let granted = await cameraService.requestAccess()
        authorizationGranted = granted
        guard granted else {
            statusMessage = "Camera access is required. Enable it in Settings."
            return
        }
        cameraService.setFilmLook(selectedLook, grain: grainStrength)
        cameraService.configureAndStart()
    }

    func setExposure(_ value: Float) {
        exposureBias = value
        cameraService.setExposureBias(value)
    }

    func applyManualExposure() {
        cameraService.setManualExposure(enabled: manualExposure, iso: isoValue, shutterSeconds: shutterSeconds)
    }

    func setRollLength(_ length: Int) {
        rollLength = length
        framesShot = 0
        UserDefaults.standard.set(0, forKey: "filmRollFramesShot")
    }

    func reloadRoll() {
        framesShot = 0
        UserDefaults.standard.set(0, forKey: "filmRollFramesShot")
        statusMessage = "New \(rollLength)-frame roll loaded · \(selectedLook.title)"
    }

    func capture() {
        guard cameraReady, !isCapturing else { return }
        guard !rollIsFull else {
            showRollFullAlert = true
            return
        }
        captureTask?.cancel()
        captureTask = Task { [weak self] in
            guard let self else { return }
            if self.timerSeconds > 0 {
                self.statusMessage = "Self timer · \(self.timerSeconds)"
                try? await Task.sleep(nanoseconds: UInt64(self.timerSeconds) * 1_000_000_000)
                if Task.isCancelled { return }
            }
            self.isCapturing = true
            self.cameraService.capture(raw: self.captureRAW && self.rawAvailable, flash: self.flashMode)
        }
    }

    private func updatePreviewLook() {
        cameraService.setFilmLook(selectedLook, grain: grainStrength)
    }

    private func processCapture(_ result: Result<CameraCapture, Error>) async {
        defer { isCapturing = false }
        do {
            let capture = try result.get()
            var developed: UIImage?
            var rawURL: URL?

            if let rawData = capture.rawData {
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("FilmCamera-\(UUID().uuidString).dng")
                try rawData.write(to: url, options: .atomic)
                rawURL = url
                if let rawFilter = CIRAWFilter(imageURL: url), let rawImage = rawFilter.outputImage {
                    developed = try? renderer.render(rawImage, look: selectedLook, grain: grainStrength,
                                                     bloom: bloomStrength, vignette: vignetteStrength)
                }
            }

            if developed == nil, let processedData = capture.processedData,
               let processedImage = UIImage(data: processedData) {
                developed = try renderer.render(processedImage, look: selectedLook, grain: grainStrength,
                                                bloom: bloomStrength, vignette: vignetteStrength)
            }

            guard let image = developed else {
                statusMessage = "RAW received, but this file could not be developed. Try JPG mode and report the device format."
                if let rawURL { try? FileManager.default.removeItem(at: rawURL) }
                return
            }

            let finalImage = renderer.crop(image, to: selectedAspectRatio.value)
            latestImage = finalImage
            let nextFrame = framesShot + 1
            let saved = await saveToPhotos(finalImage, rawURL: rawURL, frameNumber: nextFrame)
            if saved {
                framesShot = nextFrame
                UserDefaults.standard.set(nextFrame, forKey: "filmRollFramesShot")
                statusMessage = "Frame \(nextFrame)/\(rollLength) · \(selectedLook.title) · saved"
            }
            if let rawURL { try? FileManager.default.removeItem(at: rawURL) }
        } catch {
            statusMessage = "Capture failed: \(error.localizedDescription)"
        }
    }

    private func saveToPhotos(_ image: UIImage, rawURL: URL?, frameNumber: Int) async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let allowed: Bool
        if status == .authorized || status == .limited {
            allowed = true
        } else if status == .notDetermined {
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            allowed = newStatus == .authorized || newStatus == .limited
        } else {
            allowed = false
        }
        guard allowed else {
            statusMessage = "Photo developed. Allow Photos access to save it."
            return false
        }

        guard let jpeg = makeJPEGWithMetadata(image, frameNumber: frameNumber) else {
            statusMessage = "Film render completed, but JPEG export failed."
            return false
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                if let rawURL {
                    let request = PHAssetCreationRequest.forAsset()
                    let rawOptions = PHAssetResourceCreationOptions()
                    rawOptions.originalFilename = String(format: "FilmCamera_Roll_%02d_Original.dng", frameNumber)
                    request.addResource(with: .photo, fileURL: rawURL, options: rawOptions)
                    let jpegOptions = PHAssetResourceCreationOptions()
                    jpegOptions.originalFilename = String(format: "FilmCamera_%@_Frame_%02d.jpg", self.selectedLook.id, frameNumber)
                    jpegOptions.uniformTypeIdentifier = UTType.jpeg.identifier
                    request.addResource(with: .alternatePhoto, data: jpeg, options: jpegOptions)
                } else {
                    let request = PHAssetCreationRequest.forAsset()
                    let options = PHAssetResourceCreationOptions()
                    options.originalFilename = String(format: "FilmCamera_%@_Frame_%02d.jpg", self.selectedLook.id, frameNumber)
                    options.uniformTypeIdentifier = UTType.jpeg.identifier
                    request.addResource(with: .photo, data: jpeg, options: options)
                }
            }
            return true
        } catch {
            statusMessage = "Image rendered, but saving failed: \(error.localizedDescription)"
            return false
        }
    }

    private func makeJPEGWithMetadata(_ image: UIImage, frameNumber: Int) -> Data? {
        guard let cgImage = image.cgImage else { return image.jpegData(compressionQuality: 0.96) }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            return image.jpegData(compressionQuality: 0.96)
        }
        let date = ISO8601DateFormatter().string(from: Date())
        let exif: [CFString: Any] = [
            kCGImagePropertyExifDateTimeOriginal: date,
            kCGImagePropertyExifExposureTime: shutterSeconds,
            kCGImagePropertyExifISOSpeedRatings: [Int(isoValue)],
            kCGImagePropertyExifUserComment: "FilmCamera | Roll frame \(frameNumber)/\(rollLength) | \(selectedLook.title) | Grain \(Int(grainStrength * 100))% | Bloom \(Int(bloomStrength * 100))%"
        ]
        let properties: [CFString: Any] = [
            kCGImagePropertyExifDictionary: exif,
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFSoftware: "FilmCamera"]
        ]
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
