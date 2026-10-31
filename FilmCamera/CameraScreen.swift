import SwiftUI
import AVFoundation
import PhotosUI

struct CameraScreen: View {
    @EnvironmentObject private var camera: CameraViewModel
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var galleryImage: UIImage?
    @State private var showGalleryImage = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                viewfinderTools
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                ZStack {
                    CameraPreview(
                        image: camera.previewImage,
                        aspectRatio: camera.selectedAspectRatio.value,
                        showGrid: camera.showGrid
                    )
                    .padding(.horizontal, 12)

                    if !camera.authorizationGranted {
                        permissionView
                    }
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { point in
                    camera.focus(at: CGPoint(x: max(0, min(1, point.x / max(1, UIScreen.main.bounds.width))),
                                             y: max(0, min(1, point.y / max(1, UIScreen.main.bounds.height)))))
                }

                lookPicker
                captureControls

                Text(camera.statusMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 9)
                    .padding(.bottom, 10)
            }
        }
        .task { await camera.start() }
        .onChange(of: selectedPhoto) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                galleryImage = image
                showGalleryImage = true
            }
        }
        .sheet(isPresented: $camera.showSettings) {
            settingsSheet
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showGalleryImage) {
            galleryViewer
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("FILM CAMERA")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .tracking(2.2)
                Text("A slower way to see")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
            }

            Spacer()

            PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.09), in: Circle())
            }
            .accessibilityLabel("Open photo gallery")

            Button { camera.showSettings = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.09), in: Circle())
            }
            .accessibilityLabel("Camera settings")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private var viewfinderTools: some View {
        HStack {
            Menu {
                ForEach(ViewfinderAspectRatio.allCases) { ratio in
                    Button {
                        camera.selectedAspectRatio = ratio
                    } label: {
                        if camera.selectedAspectRatio == ratio {
                            Label(ratio.rawValue, systemImage: "checkmark")
                        } else {
                            Text(ratio.rawValue)
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "aspectratio")
                    Text(camera.selectedAspectRatio.rawValue)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(.white.opacity(0.09), in: Capsule())
            }

            Spacer()

            Button {
                camera.showGrid.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "grid")
                    Text("Grid")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(camera.showGrid ? .white : .white.opacity(0.65))
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(camera.showGrid ? .white.opacity(0.18) : .white.opacity(0.07), in: Capsule())
            }
        }
    }

    private var permissionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill").font(.largeTitle)
            Text("Camera access required").font(.headline)
            Text("Enable camera access in Settings to use the viewfinder.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
        .padding(28)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 18))
    }

    private var lookPicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("FILM STOCK")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.8)
                Spacer()
                Text(camera.selectedLook.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 18)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(FilmLook.all) { look in
                        Button {
                            camera.selectedLook = look
                        } label: {
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(swatch(for: look))
                                    .frame(width: 62, height: 54)
                                    .overlay {
                                        Image(systemName: look.monochrome ? "circle.lefthalf.filled" : "camera.filters")
                                            .font(.system(size: 15, weight: .light))
                                            .foregroundStyle(.white.opacity(0.78))
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(camera.selectedLook.id == look.id ? .white : .clear, lineWidth: 2)
                                    }
                                Text(look.title)
                                    .font(.system(size: 9, weight: camera.selectedLook.id == look.id ? .bold : .regular))
                                    .lineLimit(1)
                                    .foregroundStyle(.white.opacity(camera.selectedLook.id == look.id ? 1 : 0.58))
                            }
                            .frame(width: 68)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var captureControls: some View {
        HStack(spacing: 0) {
            Menu {
                Button("Flash off") { camera.flashMode = .off }
                Button("Flash on") { camera.flashMode = .on }
                Button("Flash auto") { camera.flashMode = .auto }
            } label: {
                Image(systemName: camera.flashMode == .off ? "bolt.slash" : "bolt.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 2) {
                Text("FRAME  \(camera.framesShot + 1)/\(camera.rollLength)")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
                Button { camera.capture() } label: {
                Circle()
                    .fill(.white)
                    .frame(width: 76, height: 76)
                    .overlay(Circle().stroke(.white.opacity(0.28), lineWidth: 5).padding(5))
                    .overlay {
                        if camera.isCapturing {
                            ProgressView().tint(.black)
                        }
                    }
            }
            .disabled(!camera.cameraReady || camera.isCapturing)
                .frame(maxWidth: .infinity)
            }

            Button {
                camera.captureRAW.toggle()
            } label: {
                VStack(spacing: 3) {
                    Text(camera.captureRAW ? "RAW" : "JPG")
                        .font(.system(size: 12, weight: .bold))
                    Text(camera.rawAvailable ? "FORMAT" : "JPG ONLY")
                        .font(.system(size: 7, weight: .semibold))
                        .tracking(0.7)
                }
                .foregroundStyle(camera.captureRAW ? .black : .white.opacity(0.85))
                .frame(width: 58, height: 42)
                .background(camera.captureRAW ? .white : .white.opacity(0.10), in: Capsule())
            }
            .disabled(!camera.rawAvailable)
            .opacity(camera.rawAvailable ? 1 : 0.45)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .overlay(alignment: .topTrailing) {
            Menu {
                Button("Timer off") { camera.timerSeconds = 0 }
                Button("3 seconds") { camera.timerSeconds = 3 }
                Button("10 seconds") { camera.timerSeconds = 10 }
            } label: {
                Label(camera.timerSeconds == 0 ? "Timer" : "\(camera.timerSeconds)s", systemImage: "timer")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.08), in: Capsule())
            }
            .offset(y: -32)
            .padding(.trailing, 24)
        }
    }

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("Film roll") {
                    Picker("Roll length", selection: Binding(
                        get: { camera.rollLength },
                        set: { camera.setRollLength($0) }
                    )) {
                        Text("24 frames").tag(24)
                        Text("36 frames").tag(36)
                    }
                    HStack {
                        Text("Frames remaining")
                        Spacer()
                        Text("\(camera.framesRemaining) / \(camera.rollLength)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Button("Load a new roll", systemImage: "arrow.clockwise") {
                        camera.reloadRoll()
                    }
                }

                Section("Film character / developer") {
                    developerSlider("Grain", value: Binding(
                        get: { Double(camera.grainStrength) },
                        set: { camera.grainStrength = Float($0) }
                    ), range: 0...0.65, valueText: "\(Int(camera.grainStrength * 100))%")
                    developerSlider("Bloom", value: Binding(
                        get: { Double(camera.bloomStrength) },
                        set: { camera.bloomStrength = Float($0) }
                    ), range: 0...0.8, valueText: "\(Int(camera.bloomStrength * 100))%")
                    developerSlider("Vignette", value: Binding(
                        get: { Double(camera.vignetteStrength) },
                        set: { camera.vignetteStrength = Float($0) }
                    ), range: 0...1, valueText: "\(Int(camera.vignetteStrength * 100))%")
                }

                Section("Manual exposure") {
                    Toggle("Manual shutter + ISO", isOn: $camera.manualExposure)
                    if camera.manualExposure {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text("ISO")
                                Spacer()
                                Text("\(Int(camera.isoValue))").monospacedDigit()
                            }
                            Slider(value: Binding(
                                get: { Double(camera.isoValue) },
                                set: { camera.isoValue = Float($0) }
                            ), in: 25...1600, step: 25)
                            HStack {
                                Text("Shutter")
                                Spacer()
                                Text("1/\(max(1, Int(1 / camera.shutterSeconds)))").monospacedDigit()
                            }
                            Slider(value: Binding(
                                get: { log2(camera.shutterSeconds) },
                                set: { camera.shutterSeconds = pow(2, $0) }
                            ), in: -13 ... -1, step: 0.25)
                            Text("The camera clamps values to the active lens's supported range.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle("Manual focus", isOn: $camera.manualFocus)
                    if camera.manualFocus {
                        HStack {
                            Text("Focus distance")
                            Slider(value: Binding(
                                get: { Double(camera.focusPosition) },
                                set: { camera.focusPosition = Float($0) }
                            ), in: 0...1)
                        }
                    }
                    HStack {
                        Text("Exposure compensation")
                        Slider(value: Binding(
                            get: { Double(camera.exposureBias) },
                            set: { camera.setExposure(Float($0)) }
                        ), in: -2...2, step: 0.1)
                        Text(camera.exposureBias, format: .number.precision(.fractionLength(1)))
                            .monospacedDigit()
                            .frame(width: 34)
                    }
                }

                Section("Capture") {
                    Toggle("RAW + developed JPEG", isOn: $camera.captureRAW)
                        .disabled(!camera.rawAvailable)
                    Text(camera.rawAvailable
                         ? "Preserves the camera RAW original alongside the developed film JPEG."
                         : "RAW is not available from the current camera configuration. JPEG capture remains available.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Picker("Self timer", selection: $camera.timerSeconds) {
                        Text("Off").tag(0)
                        Text("3 seconds").tag(3)
                        Text("10 seconds").tag(10)
                    }
                }

                Section("iPhone processing") {
                    LabeledContent("Apple Smart HDR / Deep Fusion", value: "iOS controlled")
                    LabeledContent("Film rendering", value: "Live + full-resolution still")
                    Text("Apple does not expose a public switch to disable every internal computational photography stage. Manual exposure uses supported AVFoundation controls; other iOS processing may still occur.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Camera controls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { camera.showSettings = false }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func developerSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, valueText: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                Spacer()
                Text(valueText).monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    private var galleryViewer: some View {
        NavigationStack {
            Group {
                if let galleryImage {
                    Image(uiImage: galleryImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.black)
                } else {
                    ContentUnavailableView("No photo selected", systemImage: "photo")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showGalleryImage = false }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func swatch(for look: FilmLook) -> LinearGradient {
        if look.monochrome {
            return LinearGradient(colors: [.gray, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if look.warmth > 0.04 {
            return LinearGradient(colors: [Color(red: 0.78, green: 0.48, blue: 0.28), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if look.saturation > 1.2 {
            return LinearGradient(colors: [Color(red: 0.25, green: 0.55, blue: 0.35), Color(red: 0.8, green: 0.55, blue: 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if look.warmth < -0.04 {
            return LinearGradient(colors: [Color(red: 0.25, green: 0.4, blue: 0.62), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(colors: [Color(red: 0.65, green: 0.58, blue: 0.45), Color(red: 0.22, green: 0.3, blue: 0.28)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
