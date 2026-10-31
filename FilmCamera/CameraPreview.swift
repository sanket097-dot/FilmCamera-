import SwiftUI
import AVFoundation

struct CameraPreview: View {
    let image: UIImage?
    let aspectRatio: CGFloat
    let showGrid: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    ProgressView().tint(.white)
                }

                if showGrid {
                    ViewfinderGrid()
                        .stroke(.white.opacity(0.55), lineWidth: 0.6)
                        .padding(.horizontal, geometry.size.width * 0.02)
                        .padding(.vertical, geometry.size.height * 0.02)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
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
