import SwiftUI
import AVFoundation
import UIKit

struct CameraPreview: View {
    let session: AVCaptureSession
    let showGrid: Bool
    let onTapFocus: (CGPoint) -> Void
    let focusLocked: Bool

    @State private var focusPoint: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                CameraPreviewLayer(session: session, onTap: { devicePoint, screenPoint in
                    onTapFocus(devicePoint)
                    focusPoint = screenPoint
                })
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    if showGrid {
                        ViewfinderGrid()
                            .stroke(.white.opacity(0.58), lineWidth: 0.7)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .allowsHitTesting(false)
                    }
                }
                .overlay {
                    if let point = focusPoint {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(focusLocked ? .yellow : .white, lineWidth: 1.5)
                            .frame(width: 62, height: 62)
                            .position(x: point.x * width, y: point.y * height)
                            .allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if focusLocked {
                        Label("AE/AF LOCK", systemImage: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.8)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.6), in: Capsule())
                            .padding(12)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.black)
    }
}

private struct CameraPreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession
    let onTap: (CGPoint, CGPoint) -> Void

    func makeUIView(context: Context) -> PreviewHostView {
        let view = PreviewHostView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        if let connection = view.previewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        view.onTap = { location in
            let point = view.previewLayer.captureDevicePointConverted(fromLayerPoint: location)
            let normalized = CGPoint(
                x: min(1, max(0, location.x / max(1, view.bounds.width))),
                y: min(1, max(0, location.y / max(1, view.bounds.height)))
            )
            onTap(point, normalized)
        }
        return view
    }

    func updateUIView(_ uiView: PreviewHostView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
        uiView.onTap = { location in
            let point = uiView.previewLayer.captureDevicePointConverted(fromLayerPoint: location)
            let normalized = CGPoint(
                x: min(1, max(0, location.x / max(1, uiView.bounds.width))),
                y: min(1, max(0, location.y / max(1, uiView.bounds.height)))
            )
            onTap(point, normalized)
        }
        if let connection = uiView.previewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }
}

private final class PreviewHostView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    var onTap: ((CGPoint) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        onTap?(gesture.location(in: self))
    }
}

private struct ViewfinderGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for fraction in [1.0 / 3.0, 2.0 / 3.0] {
            let x = rect.width * fraction
            let y = rect.height * fraction
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        return path
    }
}
