import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import Photos

struct PhotoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    @State private var exposure = 0.0
    @State private var contrast = 1.0
    @State private var saturation = 1.0
    @State private var warmth = 0.0
    @State private var highlights = 0.0
    @State private var shadows = 0.0
    @State private var saving = false
    @State private var message = ""
    private let context = CIContext()

    private var edited: UIImage {
        // Avoid allocating another full-resolution Core Image render when the editor
        // first opens with untouched controls.
        guard exposure != 0 || contrast != 1 || saturation != 1 ||
              warmth != 0 || highlights != 0 || shadows != 0 else { return image }
        guard let source = CIImage(image: image) else { return image }
        let exp = CIFilter.exposureAdjust()
        exp.inputImage = source
        exp.ev = Float(exposure)
        let controls = CIFilter.colorControls()
        controls.inputImage = exp.outputImage
        controls.contrast = Float(contrast)
        controls.saturation = Float(saturation)
        let temp = CIFilter.temperatureAndTint()
        temp.inputImage = controls.outputImage
        temp.neutral = CIVector(x: 6500 + warmth * 35, y: 0)
        temp.targetNeutral = CIVector(x: 6500, y: 0)
        var output = temp.outputImage ?? source
        if abs(highlights) > 0.001 {
            let h = CIFilter.highlightShadowAdjust()
            h.inputImage = output
            h.highlightAmount = Float(1 - highlights)
            h.shadowAmount = Float(1 + shadows)
            output = h.outputImage ?? output
        } else if abs(shadows) > 0.001 {
            let h = CIFilter.highlightShadowAdjust()
            h.inputImage = output
            h.highlightAmount = 1
            h.shadowAmount = Float(1 + shadows)
            output = h.outputImage ?? output
        }
        guard let cg = context.createCGImage(output, from: output.extent) else { return image }
        return UIImage(cgImage: cg, scale: 1, orientation: .up)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    Color.black
                    Image(uiImage: edited)
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                ScrollView {
                    VStack(spacing: 14) {
                        adjustment("Exposure", value: $exposure, range: -2...2, suffix: " EV")
                        adjustment("Contrast", value: $contrast, range: 0.5...1.6)
                        adjustment("Saturation", value: $saturation, range: 0...1.8)
                        adjustment("Temperature", value: $warmth, range: -100...100)
                        adjustment("Highlights", value: $highlights, range: -1...1)
                        adjustment("Shadows", value: $shadows, range: -1...1)
                        HStack {
                            Button("Reset") {
                                exposure = 0; contrast = 1; saturation = 1
                                warmth = 0; highlights = 0; shadows = 0
                            }
                            .buttonStyle(.bordered)
                            Spacer()
                            Button {
                                Task { await save() }
                            } label: {
                                Label(saving ? "Saving…" : "Save edited photo", systemImage: "square.and.arrow.down")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(saving)
                        }
                        if !message.isEmpty {
                            Text(message).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                }
                .frame(maxHeight: 290)
                .background(Color(uiColor: .secondarySystemBackground))
            }
            .background(.black)
            .navigationTitle("Develop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func adjustment(_ title: String, value: Binding<Double>,
                            range: ClosedRange<Double>, suffix: String = "") -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title).font(.system(size: 13, weight: .medium))
                Spacer()
                Text(value.wrappedValue.formatted(.number.precision(.fractionLength(2))) + suffix)
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    @MainActor
    private func save() async {
        saving = true
        defer { saving = false }
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let allowed: Bool
        if status == .authorized || status == .limited { allowed = true }
        else if status == .notDetermined {
            let updated = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            allowed = updated == .authorized || updated == .limited
        } else { allowed = false }
        guard allowed else { message = "Allow Photos access to save the edited image."; return }
        guard let data = edited.jpegData(compressionQuality: 0.96) else {
            message = "Could not encode the edited JPEG."; return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }
            message = "Edited JPEG saved to Photos."
        } catch {
            message = "Save failed: \(error.localizedDescription)"
        }
    }
}
