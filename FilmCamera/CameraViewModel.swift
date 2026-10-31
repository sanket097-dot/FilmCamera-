import Foundation
import SwiftUI
import AVFoundation
import Photos

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var authorizationGranted = false
    @Published var cameraReady = false
    @Published var statusMessage = "Preparing camera…"
    @Published var selectedLook: FilmLook = .portra400
    @Published var captureRAW = false
    @Published var rawAvailable = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var exposureBias: Float = 0
    @Published var isCapturing = false
    @Published var latestImage: UIImage?
    @Published var showSettings = false

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

    private func processCapture(_ result: Result<Data, Error>) async {
        defer { isCapturing = false }
        do {
            let data = try result.get()
            guard let source = UIImage(data: data) else {
                statusMessage = "Could not decode captured image."
                return
            }
            let rendered = try renderer.render(source, look: selectedLook)
            latestImage = rendered
            await saveToPhotos(rendered)
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
