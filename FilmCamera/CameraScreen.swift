import SwiftUI
import AVFoundation
import PhotosUI

struct CameraScreen: View {
    @EnvironmentObject private var camera: CameraViewModel
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var galleryImage: UIImage?
    @State private var showGalleryImage = false
    @State private var showExposure = false

    var body: some View {
        GeometryReader { geometry in
            let topInset = geometry.safeAreaInsets.top
            let bottomInset = geometry.safeAreaInsets.bottom
            let usableHeight = max(560, geometry.size.height - topInset - bottomInset)
            let previewHeight = min(usableHeight * 0.46, geometry.size.width * 1.08)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .frame(height: 48)

                CameraPreview(
                    session: camera.cameraService.session,
                    showGrid: camera.showGrid,
                    onTapFocus: { camera.setFocusPoint($0) },
                    focusLocked: camera.focusLocked
                )
                .frame(maxWidth: .infinity)
                .frame(height: previewHeight)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 10)
                .padding(.top, 8)

                cameraToolbar
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .frame(height: 56)

                exposureControl
                    .padding(.horizontal, 20)
                    .padding(.top, 2)
                    .frame(height: 30)

                filmPicker
                    .padding(.top, 7)

                Spacer(minLength: 4)

                shutterDock
                    .padding(.horizontal, 22)
                    .frame(height: 82)

                Text(camera.statusMessage)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 20)
                    .frame(height: 17)
                    .padding(.top, 2)
            }
            .padding(.top, topInset + 5)
            .padding(.bottom, bottomInset + 4)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .background(Color.black)
            .overlay {
                if !camera.authorizationGranted && !camera.cameraReady {
                    permissionView
                }
            }
        }
        .ignoresSafeArea()
        .background(Color.black)
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
        .sheet(isPresented: $showExposure) {
            exposureSheet.presentationDetents([.height(190)])
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("FILM CAMERA")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .tracking(2)
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
            .frame(width: 40, height: 40)
            .background(.white.opacity(0.10), in: Circle())
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
        .background(.black.opacity(0.92), in: RoundedRectangle(cornerRadius: 18))
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

            Button { showExposure = true } label: {
                toolbarItem("sun.max", title: String(format: "%+.1f", camera.exposureBias), active: true)
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Adjust exposure")
        }
        .buttonStyle(.plain)
    }

    private func toolbarItem(_ symbol: String, title: String, active: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .regular))
                .frame(height: 21)
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .tracking(0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(active ? .white : .white.opacity(0.52))
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var exposureControl: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
            Text("EXPOSURE")
                .font(.system(size: 8, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.65))
            Spacer()
            Text(String(format: "%+.1f EV", camera.exposureBias))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
            Button("Reset") { camera.setExposure(0) }
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var exposureSheet: some View {
        VStack(spacing: 18) {
            HStack {
                Text("Exposure compensation")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text(String(format: "%+.1f EV", camera.exposureBias))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: Binding(
                get: { Double(camera.exposureBias) },
                set: { camera.setExposure(Float($0)) }
            ), in: -2...2, step: 0.1)
            HStack {
                Text("−2 EV").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Reset") { camera.setExposure(0) }
                Spacer()
                Text("+2 EV").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .padding(.top, 8)
        .background(Color(uiColor: .secondarySystemBackground))
        .preferredColorScheme(.dark)
    }

    private var filmPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("FILM STOCK")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.6)
                Spacer()
                Text(camera.selectedLook.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(FilmLook.all) { look in
                        Button { camera.selectedLook = look } label: {
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(swatch(for: look))
                                    .frame(width: 72, height: 42)
                                    .overlay {
                                        Image(systemName: look.monochrome ? "circle.lefthalf.filled" : "camera.filters")
                                            .font(.system(size: 15, weight: .light))
                                            .foregroundStyle(.white.opacity(0.88))
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .stroke(camera.selectedLook.id == look.id ? .white : .white.opacity(0.15),
                                                    lineWidth: camera.selectedLook.id == look.id ? 2 : 1)
                                    }
                                Text(look.title)
                                    .font(.system(size: 8, weight: camera.selectedLook.id == look.id ? .bold : .regular))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.white.opacity(camera.selectedLook.id == look.id ? 1 : 0.58))
                            }
                            .frame(width: 76)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Select \(look.title) film stock")
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 3)
            }
            .frame(height: 62)
        }
    }

    private var shutterDock: some View {
        HStack(alignment: .center) {
            PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 66)
                    .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Open photo library")

            Button { camera.capture() } label: {
                ZStack {
                    Circle().fill(.white).frame(width: 72, height: 72)
                    Circle().stroke(.black.opacity(0.16), lineWidth: 2).frame(width: 62, height: 62)
                    if camera.isCapturing {
                        ProgressView().tint(.black)
                    }
                }
                .frame(width: 82, height: 78)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!camera.cameraReady || camera.isCapturing)
            .opacity(camera.cameraReady ? 1 : 0.45)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Take photo")

            Button { camera.captureRAW.toggle() } label: {
                VStack(spacing: 2) {
                    Text(camera.captureRAW && camera.rawAvailable ? "RAW" : "JPG")
                        .font(.system(size: 11, weight: .bold))
                    Text("FORMAT")
                        .font(.system(size: 7, weight: .semibold))
                        .tracking(0.6)
                }
                .foregroundStyle(.white)
                .frame(width: 58, height: 42)
                .background(.white.opacity(0.12), in: Capsule())
            }
            .disabled(!camera.rawAvailable)
            .opacity(camera.rawAvailable ? 1 : 0.55)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Capture format")
        }
        .frame(height: 82)
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
                         ? "The original RAW and developed film JPEG are saved together."
                         : "RAW is not available from the current camera configuration.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Camera behavior") {
                    LabeledContent("Live preview", value: "Natural iPhone camera feed")
                    LabeledContent("Film look", value: "Applied after capture")
                    Text("Tap the viewfinder to set focus and metering. Use the sun control for exposure compensation.")
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
