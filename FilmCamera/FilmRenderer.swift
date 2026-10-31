import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

final class FilmRenderer {
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    func render(_ image: UIImage, look: FilmLook) throws -> UIImage {
        guard var ciImage = CIImage(image: image) else {
            throw RenderError.invalidImage
        }

        // Work in the source image's extent; all processing is non-destructive.
        let extent = ciImage.extent

        if look.monochrome {
            let mono = CIFilter.photoEffectNoir()
            mono.inputImage = ciImage
            ciImage = mono.outputImage ?? ciImage
        }

        let color = CIFilter.colorControls()
        color.inputImage = ciImage
        color.saturation = CGFloat(look.saturation)
        color.contrast = CGFloat(look.contrast)
        color.brightness = CGFloat(look.brightness)
        ciImage = color.outputImage ?? ciImage

        if abs(look.warmth) > 0.001 {
            let temp = CIFilter.temperatureAndTint()
            temp.inputImage = ciImage
            temp.neutral = CIVector(x: 6500, y: 0)
            temp.targetNeutral = CIVector(x: 6500 + CGFloat(look.warmth * 1200), y: 0)
            ciImage = temp.outputImage ?? ciImage
        }

        if look.fade > 0 {
            let controls = CIFilter.colorControls()
            controls.inputImage = ciImage
            controls.saturation = 1
            controls.contrast = 1 - (look.fade * 0.45)
            controls.brightness = CGFloat(look.fade * 0.10)
            ciImage = controls.outputImage ?? ciImage
        }

        // Subtle grain starter: CI noise is blended at low opacity.
        if look.grain > 0 {
            let noise = CIFilter.randomGenerator()
            if let noiseImage = noise.outputImage?.cropped(to: extent) {
                let monoNoise = CIFilter.colorControls()
                monoNoise.inputImage = noiseImage
                monoNoise.saturation = 0
                monoNoise.contrast = 1.3
                let blend = CIFilter.softLightBlendMode()
                blend.inputImage = monoNoise.outputImage?.applyingFilter(
                    "CIColorMatrix",
                    parameters: [
                        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(look.grain))
                    ])
                blend.backgroundImage = ciImage
                ciImage = blend.outputImage ?? ciImage
            }
        }

        guard let cgImage = context.createCGImage(ciImage, from: extent) else {
            throw RenderError.renderFailed
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
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
