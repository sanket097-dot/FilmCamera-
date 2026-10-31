import SwiftUI
import AVFoundation

struct CameraPreview: View {
    let image: UIImage?
    let aspectRatio: CGFloat
    let showGrid: Bool
    let onTapFocus: (CGPoint) -> Void
    let focusLocked: Bool

    @State private var focusPoint: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            let available = proxy.size
            let ratio = max(0.5, min(2.4, aspectRatio))
            let width = min(available.width, available.height * ratio)
            let height = width / ratio

            ZStack {
                Color.black
                ZStack {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: width, height: height)
                            .clipped()
                    } else {
                        ProgressView().tint(.white)
                            .frame(width: width, height: height)
                    }

                    if showGrid {
                        ViewfinderGrid()
                            .stroke(.white.opacity(0.58), lineWidth: 0.6)
                            .frame(width: width, height: height)
                            .allowsHitTesting(false)
                    }

                    if let point = focusPoint {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(focusLocked ? .yellow : .white, lineWidth: 1.5)
                            .frame(width: 62, height: 62)
                            .position(point)
                            .allowsHitTesting(false)
                    }

                    VStack {
                        HStack {
                            Spacer()
                            if focusLocked {
                                Label("AE/AF LOCK", systemImage: "lock.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(0.8)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(.black.opacity(0.55), in: Capsule())
                            }
                        }
                        Spacer()
                    }
                    .padding(12)
                    .frame(width: width, height: height)
                    .allowsHitTesting(false)
                }
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture { location in
                    focusPoint = location
                    onTapFocus(CGPoint(x: location.x / width, y: location.y / height))
                }
                .frame(width: width, height: height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.black)
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
