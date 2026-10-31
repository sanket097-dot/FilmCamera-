import SwiftUI
import AVFoundation
import PhotosUI

struct CameraScreen: View {
    @EnvironmentObject private var camera: CameraViewModel
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var galleryImage: UIImage?
    @State private var showGalleryImage = false

    var body: some View {
        GeometryReader { geometry in
            let portraitRatio = camera.selectedAspectRatio.portraitValue
            let previewHeight = min(geometry.size.height * 0.56, geometry.size.width / portraitRatio)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 5)
                    .padding(.bottom, 10)

                ZStack {
                    CameraPreview(
                        session: camera.cameraService.session,
                        aspectRatio: portraitRatio,
                        showGrid: camera.showGrid,
                        onTapFocus: { camera.setFocusPoint($0) },
                        focusLocked: camera.focusLocked
                    )
                    .frame(height: previewHeight)

                    if !camera.authorizationGranted {
                        permissionView
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)

                cameraToolbar
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                exposureControl
                    .padding(.horizontal, 20)
                    .padding(.top, 5)

                filmPicker
                    .padding(.top, 10)

                shutterDock
                    .padding(.horizontal, 20)
                    .padding(.top, 9)
                    .padding(.bottom, 3)

                Text(camera.statusMessage)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(1)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.black)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
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
            settingsSheet.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showGalleryImage) {
            galleryViewer
        }
        .sheet(isPresented: $camera.showEditor) {
            if let image = camera.latestImage {
                PhotoEditorView(image: image)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("FILM CAMERA")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .tracking(2.1)
                Text("A slower way to see")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
            }
            Spacer()
            PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                headerIcon("photo.on.rectangle")
            }
            .accessibilityLabel("Open photo library")
            Button { camera.showSettings = true } label: {
                headerIcon("slider.horizontal.3")
            }
            .accessibilityLabel("Camera settings")
        }
        .foregroundStyle(.white)
    }

    private func headerIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 17, weight: .medium))
            .frame(width: 42, height: 42)
            .background(.white.opacity(0.09), in: Circle())
    }

    private var permissionView: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.fill").font(.largeTitle)
            Text("Camera access required").font(.headline)
            Text("Enable camera access in Settings to use Film Camera.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
        .padding(24)
        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 18))
    }

    private var cameraToolbar: some View {
        HStack(spacing: 0) {
            Button {
                camera.flashMode = camera.flashMode == .off ? .on : .off
            } label: {
                toolbarItem(camera.flashMode == .on ? "bolt.fill" : "bolt.slash",
                            title: "FLASH", active: camera.flashMode == .on)
            }
            .frame(maxWidth: .infinity)

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
                toolbarItem("aspectratio", title: camera.selectedAspectRatio.rawValue, active: true)
            }
            .frame(maxWidth: .infinity)

            Button { camera.showGrid.toggle() } label: {
                toolbarItem("grid", title: "GRID", active: camera.showGrid)
            }
            .frame(maxWidth: .infinity)

            Button { camera.toggleFocusLock() } label: {
                toolbarItem(camera.focusLocked ? "lock.fill" : "viewfinder",
                            title: camera.focusLocked ? "LOCKED" : "FOCUS",
                            active: camera.focusLocked)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func toolbarItem(_ symbol: String, title: String, active: Bool) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .regular))
                .frame(height: 22)
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .tracking(0.8)
        }
        .foregroundStyle(active ? .white : .white.opacity(0.55))
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var exposureControl: some View {
        HStack(spacing: 10) {
            Image(systemName: "sun.max")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            Slider(value: Binding(
                get: { Double(camera.exposureBias) },
                set: { camera.setExposure(Float($0)) }
            ), in: -2...2, step: 0.1)
            Text(camera.exposureBias.formatted(.number.precision(.fractionLength(1))) + " EV")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 49, alignment: .trailing)
        }
        .frame(height: 30)
        .accessibilityLabel("Exposure compensation")
    }

    private var filmPicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("FILM STOCK")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.8)
                Spacer()
                Text(camera.selectedLook.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .foregroundStyle(.white.opacity(0.88))
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(FilmLook.all) { look in
                        Button { camera.selectedLook = look } label: {
                            VStack(spacing: 5) {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(swatch(for: look))
                                    .frame(width: 66, height: 48)
                                    .overlay {
                                        Image(systemName: look.monochrome ? "circle.lefthalf.filled" : "camera.filters")
                                            .font(.system(size: 16, weight: .light))
                                            .foregroundStyle(.white.opacity(0.82))
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .stroke(camera.selectedLook.id == look.id ? .white : .clear, lineWidth: 2)
                                    }
                                Text(look.title)
                                    .font(.system(size: 9, weight: camera.selectedLook.id == look.id ? .bold : .regular))
                                    .lineLimit(1)
                                    .foregroundStyle(.white.opacity(camera.selectedLook.id == look.id ? 1 : 0.58))
                            }
                            .frame(width: 70)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
            }
        }
    }

    private var shutterDock: some View {
        HStack(alignment: .center) {
            PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                Image(systemName: "photo")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
            }
            .frame(maxWidth: .infinity)

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
            .accessibilityLabel("Take photo")

            Button { camera.captureRAW.toggle() } label: {
                VStack(spacing: 3) {
                    Text(camera.captureRAW ? "RAW" : "JPG")
                        .font(.system(size: 12, weight: .bold))
                    Text("FORMAT")
                        .font(.system(size: 7, weight: .semibold))
                        .tracking(0.8)
                }
                .foregroundStyle(camera.captureRAW ? .black : .white)
                .frame(width: 62, height: 43)
                .background(camera.captureRAW ? .white : .white.opacity(0.10), in: Capsule())
            }
            .disabled(!camera.rawAvailable)
            .opacity(camera.rawAvailable ? 1 : 0.45)
            .frame(maxWidth: .infinity)
        }
    }

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("Film character") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Grain")
                            Spacer()
                            Text("\(Int(camera.grainStrength * 100))%")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(camera.grainStrength) },
                            set: { camera.grainStrength = Float($0) }
                        ), in: 0...0.65, step: 0.01)
                        Text("Film grain is applied to the developed capture. The live viewfinder stays natural and clear.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Capture") {
                    Toggle("RAW + developed JPEG", isOn: $camera.captureRAW)
                        .disabled(!camera.rawAvailable)
                    Text(camera.rawAvailable
                         ? "The camera stores the original RAW and a developed film JPEG. The viewfinder uses Apple's normal camera preview."
                         : "RAW is not available from the current camera configuration.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Camera behavior") {
                    LabeledContent("Live preview", value: "Natural iPhone camera feed")
                    LabeledContent("Film look", value: "Applied after capture")
                    LabeledContent("Exposure compensation", value: "Live sensor control")
                    Text("The live preview uses AVCaptureVideoPreviewLayer so it shows the normal ISP-processed camera image rather than a flat RAW decode.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Camera settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { camera.showSettings = false }
                }
            }
        }
        .preferredColorScheme(.dark)
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
