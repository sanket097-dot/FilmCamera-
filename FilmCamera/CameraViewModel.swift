import Foundation
import SwiftUI
import AVFoundation
import Photos
import UIKit
import CoreImage
import UniformTypeIdentifiers

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
    // The camera is held vertically: 4:3 means a portrait 3:4 frame.
    var portraitValue: CGFloat { value == 1 ? 1 : 1 / value }
}

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var authorizationGranted = false
    @Published var cameraReady = false
    @Published var statusMessage = "Preparing camera…"
    @Published var selectedLook: FilmLook = .portra400
    @Published var captureRAW = true
    @Published var rawAvailable = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var exposureBias: Float = -0.3
    @Published var isCapturing = false
    @Published var latestImage: UIImage?
    @Published var previewImage: UIImage?
    @Published var showSettings = false
    @Published var grainStrength: Float = 0.12
    @Published var selectedAspectRatio: ViewfinderAspectRatio = .ratio4x3
    @Published var showGrid = false
    @Published var focusLocked = false
    @Published var manualFocus: Float = 0.5
    @Published var showEditor = false

    let cameraService = CameraService()
    private let renderer = FilmRenderer()
    private let previewRenderQueue = DispatchQueue(label: "film.camera.live-render", qos: .userInitiated)

    init() {
        cameraService.onStateChange = { [weak self] ready, raw, message in
            Task { @MainActor in
                self?.cameraReady = ready
                self?.rawAvailable = raw
                self?.captureRAW = raw
                self?.statusMessage = message
            }
        }
        cameraService.onCapture = { [weak self] result in
            Task { @MainActor in await self?.processCapture(result) }
        }
        cameraService.onPreviewFrame = { [weak self] frame in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let look = self.selectedLook
                self.previewRenderQueue.async { [weak self] in
                    guard let self, let image = self.renderer.renderPreview(frame, look: look) else { return }
                    DispatchQueue.main.async { [weak self] in self?.previewImage = image }
                }
            }
        }
    }

    func start() async {
        let granted = await cameraService.requestAccess()
        authorizationGranted = granted
        guard granted else {
            statusMessage = "Camera access is required. Enable it in Settings."
            return
        }
        cameraService.configureAndStart()
        cameraService.setExposureBias(exposureBias)
    }

    func setExposure(_ value: Float) {
        exposureBias = value
        cameraService.setExposureBias(value)
    }

    func setFocusPoint(_ point: CGPoint) {
        guard !focusLocked else { return }
        cameraService.setFocusAndExposure(point: point)
    }

    func toggleFocusLock() {
        focusLocked.toggle()
        cameraService.setFocusLocked(focusLocked)
    }

    func setManualFocus(_ value: Float) {
        manualFocus = value
        cameraService.setManualFocus(value)
    }

    func capture() {
        guard cameraReady, !isCapturing else { return }
        isCapturing = true
        cameraService.capture(raw: captureRAW && rawAvailable, flash: flashMode)
    }

    private func processCapture(_ result: Result<CameraCapture, Error>) async {
        defer { isCapturing = false }
        do {
            let capture = try result.get()
            var developed: UIImage?
            var rawURL: URL?

            // Preserve the original DNG without decoding it in memory. Developing a
            // full-resolution Bayer/ProRAW frame on the UI actor can exhaust phone memory.
            if let rawData = capture.rawData {
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("FilmCamera-\\(UUID().uuidString).dng")
                try rawData.write(to: url, options: .atomic)
                rawURL = url
            }

            // Use the camera's processed companion JPEG for the film-developed output.
            if let processedData = capture.processedData,
               let processedImage = UIImage(data: processedData) {
                developed = try renderer.render(processedImage, look: selectedLook, grain: grainStrength)
            }

            guard let image = developed else {
                statusMessage = "Capture received, but the processed JPEG could not be developed."
                if let rawURL { try? FileManager.default.removeItem(at: rawURL) }
                return
            }

            let finalImage = renderer.crop(image, to: selectedAspectRatio.portraitValue)
            latestImage = finalImage
            showEditor = true
            await saveToPhotos(finalImage, rawURL: rawURL)
            if let rawURL { try? FileManager.default.removeItem(at: rawURL) }
        } catch {
            statusMessage = "Capture failed: \(error.localizedDescription)"
        }
    }

    private func saveToPhotos(_ image: UIImage, rawURL: URL?) async {
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
            return
        }

        guard let jpeg = image.jpegData(compressionQuality: 0.96) else {
            statusMessage = "Film render completed, but JPEG export failed."
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                // Save the developed film JPEG as a normal photo asset.
                let jpegRequest = PHAssetCreationRequest.forAsset()
                let jpegOptions = PHAssetResourceCreationOptions()
                jpegOptions.originalFilename = "FilmCamera-\\(self.selectedLook.id).jpg"
                jpegOptions.uniformTypeIdentifier = UTType.jpeg.identifier
                jpegRequest.addResource(with: .photo, data: jpeg, options: jpegOptions)

                // Save the untouched DNG as its own RAW asset. Keeping the two assets
                // separate avoids fragile RAW/JPEG alternate-resource pairing.
                if let rawURL {
                    let rawRequest = PHAssetCreationRequest.forAsset()
                    let options = PHAssetResourceCreationOptions()
                    options.originalFilename = "FilmCamera-Original.dng"
                    options.uniformTypeIdentifier = "com.adobe.raw-image"
                    rawRequest.addResource(with: .photo, fileURL: rawURL, options: options)
                }
            }
            statusMessage = rawURL == nil
                ? "Saved developed \(selectedLook.title) JPEG."
                : "Saved developed \(selectedLook.title) JPEG + original DNG."
        } catch {
            statusMessage = "Image rendered, but saving failed: \(error.localizedDescription)"
        }
    }
}
