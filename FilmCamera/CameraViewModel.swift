import Foundation
import SwiftUI
import AVFoundation
import Photos
import UIKit

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
    @Published var selectedLook: FilmLook = .portra400 {
        didSet { updatePreviewLook() }
    }
    @Published var captureRAW = false
    @Published var rawAvailable = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var exposureBias: Float = 0
    @Published var isCapturing = false
    @Published var latestImage: UIImage?
    @Published var previewImage: UIImage?
    @Published var showSettings = false
    @Published var grainStrength: Float = 0.12 {
        didSet { updatePreviewLook() }
    }
    @Published var selectedAspectRatio: ViewfinderAspectRatio = .ratio4x3
    @Published var showGrid = false

    let cameraService = CameraService()
    private let renderer = FilmRenderer()

    init() {
        cameraService.onStateChange = { [weak self] ready, raw, message in
            Task { @MainActor in
                self?.cameraReady = ready
                self?.rawAvailable = raw
                if !raw { self?.captureRAW = false }
                self?.statusMessage = message
            }
        }
        cameraService.onVideoFrame = { [weak self] image in
            Task { @MainActor in self?.previewImage = image }
        }
        cameraService.onCapture = { [weak self] result in
            Task { @MainActor in
                await self?.processCapture(result)
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
        cameraService.setFilmLook(selectedLook, grain: grainStrength)
        cameraService.configureAndStart()
    }

    func setExposure(_ value: Float) {
        exposureBias = value
        cameraService.setExposureBias(value)
    }

    func capture() {
        guard cameraReady, !isCapturing else { return }
        isCapturing = true
        cameraService.capture(raw: captureRAW, flash: flashMode)
    }

    private func updatePreviewLook() {
        cameraService.setFilmLook(selectedLook, grain: grainStrength)
    }

    private func processCapture(_ result: Result<Data, Error>) async {
        defer { isCapturing = false }
        do {
            let data = try result.get()
            guard let source = UIImage(data: data) else {
                statusMessage = captureRAW
                    ? "RAW file captured, but this version cannot develop the DNG yet. Turn RAW off to save a film-rendered photo."
                    : "Could not decode captured image."
                return
            }
            let rendered = try renderer.render(source, look: selectedLook, grain: grainStrength)
            let finalImage = renderer.crop(rendered, to: selectedAspectRatio.value)
            latestImage = finalImage
            await saveToPhotos(finalImage)
        } catch {
            statusMessage = "Capture failed: \(error.localizedDescription)"
        }
    }

    private func saveToPhotos(_ image: UIImage) async {
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
            statusMessage = "Photo captured. Allow Photos access to save it."
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            statusMessage = "Saved with \(selectedLook.title)."
        } catch {
            statusMessage = "Image rendered, but saving failed: \(error.localizedDescription)"
        }
    }
}
