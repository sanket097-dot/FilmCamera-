import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

final class FilmRenderer {
    private let context = CIContext(options: [.useSoftwareRenderer: false, .cacheIntermediates: true])
    private var cubeCache: [String: Data] = [:]
    private let cacheLock = NSLock()

    func render(_ image: UIImage, look: FilmLook, grain: Float? = nil) throws -> UIImage {
        guard let source = CIImage(image: image) else { throw RenderError.invalidImage }
        return try render(source, look: look, grain: grain ?? look.grain, orientation: image.imageOrientation)
    }

    func render(_ source: CIImage, look: FilmLook, grain: Float? = nil,
                orientation: UIImage.Orientation = .up) throws -> UIImage {
        let output = applying(look, to: source, grain: grain ?? look.grain)
        guard let cgImage = context.createCGImage(output, from: output.extent) else {
            throw RenderError.renderFailed
        }
        return UIImage(cgImage: cgImage, scale: 1, orientation: orientation)
    }

    func applying(_ look: FilmLook, to source: CIImage, grain: Float) -> CIImage {
        let extent = source.extent
        var image = source

        // Film-specific 3D colour transform. This is a measured-profile-ready hybrid LUT
        // architecture; the current stock curves are carefully shaped approximations.
        if let cube = colorCube(for: look) {
            let filter = CIFilter.colorCube()
            filter.inputImage = image
            filter.cubeDimension = 17
            filter.cubeData = cube
            image = filter.outputImage ?? image
        }

        if look.monochrome {
            let mono = CIFilter.photoEffectNoir()
            mono.inputImage = image
            image = mono.outputImage ?? image
        }

        if look.fade > 0.001 {
            let fade = CIFilter.colorControls()
            fade.inputImage = image
            fade.saturation = 1
            fade.contrast = 1 - look.fade * 0.30
            fade.brightness = look.fade * 0.035
            image = fade.outputImage ?? image
        }

        // Gentle highlight bloom and a warm red halation approximation for tungsten stocks.
        let bloomAmount: Float = look.id == "tungsten800" ? 0.20 : 0.08
        let bloom = CIFilter.bloom()
        bloom.inputImage = image
        bloom.radius = 7
        bloom.intensity = bloomAmount
        image = bloom.outputImage?.cropped(to: extent) ?? image

        let amount = max(0, min(0.65, grain))
        if amount > 0.001 {
            let noise = CIFilter.randomGenerator()
            if let noiseImage = noise.outputImage?.cropped(to: extent) {
                let monoNoise = CIFilter.colorControls()
                monoNoise.inputImage = noiseImage
                monoNoise.saturation = 0
                monoNoise.contrast = 1.6
                let matrix = CIFilter.colorMatrix()
                matrix.inputImage = monoNoise.outputImage
                matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: CGFloat(amount * 0.22))
                let blend = CIFilter.softLightBlendMode()
                blend.inputImage = matrix.outputImage
                blend.backgroundImage = image
                image = blend.outputImage?.cropped(to: extent) ?? image
            }
        }

        let vignette = CIFilter.vignette()
        vignette.inputImage = image
        vignette.intensity = 0.18
        vignette.radius = Float(max(extent.width, extent.height) * 0.72)
        image = vignette.outputImage?.cropped(to: extent) ?? image
        return image.cropped(to: extent)
    }

    private func colorCube(for look: FilmLook) -> Data? {
        cacheLock.lock()
        if let cached = cubeCache[look.id] { cacheLock.unlock(); return cached }
        cacheLock.unlock()

        let dimension = 17
        var values = [Float]()
        values.reserveCapacity(dimension * dimension * dimension * 4)
        let warmth = look.warmth
        let saturation = look.saturation
        let contrast = look.contrast
        let brightness = look.brightness

        for blue in 0..<dimension {
            for green in 0..<dimension {
                for red in 0..<dimension {
                    var r = Float(red) / Float(dimension - 1)
                    var g = Float(green) / Float(dimension - 1)
                    var b = Float(blue) / Float(dimension - 1)

                    // Film-like toe and shoulder, preserving highlight detail more gently than a basic contrast slider.
                    func curve(_ x: Float) -> Float {
                        let centered = (x - 0.5) * contrast + 0.5 + brightness
                        let toe = centered / (max(0.0001, centered + 0.055))
                        let normalizedToe = toe / 1.052
                        let shoulder = normalizedToe / (1 + max(0, normalizedToe - 0.72) * 0.30)
                        return min(1, max(0, shoulder))
                    }
                    r = curve(r); g = curve(g); b = curve(b)
                    let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
                    r = luma + (r - luma) * saturation
                    g = luma + (g - luma) * saturation
                    b = luma + (b - luma) * saturation

                    let shadowWeight = 1 - luma
                    let highlightWeight = luma
                    r += warmth * 0.16 + (look.id == "tungsten800" ? 0.035 * highlightWeight : 0)
                    b -= warmth * 0.13
                    g += (look.id == "superia400" ? 0.018 * shadowWeight : 0)
                    r += (look.id == "portra400" ? 0.018 * shadowWeight : 0)
                    g += (look.id == "gold200" ? 0.018 * highlightWeight : 0)
                    b += (look.id == "pro400h" ? 0.025 * highlightWeight : 0)
                    if look.monochrome {
                        let mono = 0.24 * r + 0.68 * g + 0.08 * b
                        r = mono; g = mono; b = mono
                    }
                    values.append(min(1, max(0, r)))
                    values.append(min(1, max(0, g)))
                    values.append(min(1, max(0, b)))
                    values.append(1)
                }
            }
        }
        let data = values.withUnsafeBufferPointer { Data(buffer: $0) }
        cacheLock.lock(); cubeCache[look.id] = data; cacheLock.unlock()
        return data
    }

    func crop(_ image: UIImage, to aspectRatio: CGFloat) -> UIImage {
        guard aspectRatio > 0 else { return image }
        // Normalize UIImage orientation before calculating the crop. Camera JPEGs commonly
        // store portrait orientation as metadata while their underlying pixels remain landscape.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let normalized = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        guard let source = CIImage(image: normalized) else { return image }
        let extent = source.extent
        let currentRatio = extent.width / extent.height
        let cropRect: CGRect
        if currentRatio > aspectRatio {
            let width = extent.height * aspectRatio
            cropRect = CGRect(x: extent.midX - width / 2, y: extent.minY, width: width, height: extent.height)
        } else {
            let height = extent.width / aspectRatio
            cropRect = CGRect(x: extent.minX, y: extent.midY - height / 2, width: extent.width, height: height)
        }
        guard let cgImage = context.createCGImage(source.cropped(to: cropRect), from: cropRect) else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }

    enum RenderError: LocalizedError {
        case invalidImage
        case renderFailed
        var errorDescription: String? {
            switch self {
            case .invalidImage: return "The source image could not be read."
            case .renderFailed: return "The film rendering operation failed."
            }
        }
    }
}
