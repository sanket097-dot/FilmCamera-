import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

final class FilmRenderer {
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    func render(_ image: UIImage, look: FilmLook, grain: Float? = nil) throws -> UIImage {
        guard let source = CIImage(image: image) else {
            throw RenderError.invalidImage
        }
        let ciImage = applying(look, to: source, grain: grain ?? look.grain)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw RenderError.renderFailed
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    func applying(_ look: FilmLook, to source: CIImage, grain: Float) -> CIImage {
        var image = source
        let extent = source.extent

        if look.monochrome {
            let mono = CIFilter.photoEffectNoir()
            mono.inputImage = image
            image = mono.outputImage ?? image
        }

        let color = CIFilter.colorControls()
        color.inputImage = image
        color.saturation = look.saturation
        color.contrast = look.contrast
        color.brightness = look.brightness
        image = color.outputImage ?? image

        if abs(look.warmth) > 0.001 {
            let temp = CIFilter.temperatureAndTint()
            temp.inputImage = image
            temp.neutral = CIVector(x: 6500, y: 0)
            temp.targetNeutral = CIVector(x: 6500 + CGFloat(look.warmth * 1200), y: 0)
            image = temp.outputImage ?? image
        }

        if look.fade > 0 {
            let fade = CIFilter.colorControls()
            fade.inputImage = image
            fade.saturation = 1
            fade.contrast = 1 - (look.fade * 0.45)
            fade.brightness = look.fade * 0.10
            image = fade.outputImage ?? image
        }

        let amount = max(0, min(0.65, grain))
        if amount > 0.001 {
            let noise = CIFilter.randomGenerator()
            if let noiseImage = noise.outputImage?.cropped(to: extent) {
                let monoNoise = CIFilter.colorControls()
                monoNoise.inputImage = noiseImage
                monoNoise.saturation = 0
                monoNoise.contrast = 1.3

                let alpha = monoNoise.outputImage?.applyingFilter(
                    "CIColorMatrix",
                    parameters: [
                        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(amount))
                    ])
                let blend = CIFilter.softLightBlendMode()
                blend.inputImage = alpha
                blend.backgroundImage = image
                image = blend.outputImage?.cropped(to: extent) ?? image
            }
        }
        return image.cropped(to: extent)
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
