import SwiftUI
import AVFoundation

struct CameraScreen: View {
    @EnvironmentObject private var camera: CameraViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ZStack {
                    CameraPreview(session: camera.cameraService.session)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .padding(.horizontal, 12)

                    if !camera.authorizationGranted {
                        permissionView
                    }
                }
                .frame(maxHeight: .infinity)

                lookPicker
                captureControls
                Text(camera.statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(2)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }
        }
        .task { await camera.start() }
        .sheet(isPresented: $camera.showSettings) {
            settingsSheet
                .presentationDetents([.medium, .large])
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("FILM CAMERA")
                    .font(.headline.weight(.bold))
                    .tracking(2)
                Text("Capture with intention")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            Button { camera.showSettings = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.10), in: Circle())
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var permissionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill").font(.largeTitle)
            Text("Camera access required")
                .font(.headline)
            Text("Enable camera access in Settings to use the viewfinder.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
        .padding(28)
        .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 16))
    }

    private var lookPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("FILM SIMULATION")
                    .font(.caption.weight(.semibold))
                    .tracking(1.4)
                Spacer()
                Text(camera.selectedLook.title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(FilmLook.all) { look in
                        Button {
                            camera.selectedLook = look
                        } label: {
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(look.monochrome
                                          ? LinearGradient(colors: [.gray, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                                          : LinearGradient(colors: swatch(for: look), startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 58, height: 48)
                                    .overlay {
                                        if camera.selectedLook.id == look.id {
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(.white, lineWidth: 2)
                                        }
                                    }
                                Text(look.title)
                                    .font(.system(size: 9, weight: camera.selectedLook.id == look.id ? .bold : .regular))
                                    .lineLimit(1)
                                    .foregroundStyle(.white.opacity(camera.selectedLook.id == look.id ? 1 : 0.65))
                            }
                            .frame(width: 66)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var captureControls: some View {
        HStack(spacing: 26) {
            Button {
                camera.flashMode = camera.flashMode == .off ? .on : .off
            } label: {
                Image(systemName: camera.flashMode == .on ? "bolt.fill" : "bolt.slash")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
            }

            Button { camera.capture() } label: {
                Circle()
                    .fill(.white)
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(.white.opacity(0.45), lineWidth: 5).padding(5))
                    .overlay {
                        if camera.isCapturing {
                            ProgressView().tint(.black)
                        }
                    }
            }
            .disabled(!camera.cameraReady || camera.isCapturing)

            Button {
                camera.captureRAW.toggle()
            } label: {
                Text(camera.captureRAW ? "RAW" : "JPG")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(camera.captureRAW ? .black : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(camera.captureRAW ? .white : .white.opacity(0.12), in: Capsule())
            }
            .disabled(!camera.rawAvailable)
            .opacity(camera.rawAvailable ? 1 : 0.4)
        }
        .padding(.top, 10)
    }

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("Capture format") {
                    Toggle("RAW (if supported)", isOn: $camera.captureRAW)
                        .disabled(!camera.rawAvailable)
                    Text(camera.rawAvailable
                         ? "RAW is available for the active camera configuration."
                         : "RAW is not exposed by this camera configuration. Processed capture remains available.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Exposure") {
                    HStack {
                        Text("EV")
                        Slider(value: Binding(
                            get: { Double(camera.exposureBias) },
                            set: { camera.setExposure(Float($0)) }
                        ), in: -2...2, step: 0.1)
                        Text(camera.exposureBias, format: .number.precision(.fractionLength(1)))
                            .monospacedDigit()
                            .frame(width: 38)
                    }
                }

                Section("Processing controls") {
                    LabeledContent("Film rendering", value: "Applied after capture")
                    LabeledContent("Internal HDR / Deep Fusion", value: "Controlled by iOS")
                    LabeledContent("Sharpening / noise reduction", value: "Future app pipeline controls")
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

    private func swatch(for look: FilmLook) -> [Color] {
        if look.warmth > 0.04 { return [Color(red: 0.78, green: 0.48, blue: 0.28), .black] }
        if look.saturation > 1.2 { return [Color(red: 0.25, green: 0.55, blue: 0.35), Color(red: 0.8, green: 0.55, blue: 0.2)] }
        if look.warmth < -0.04 { return [Color(red: 0.25, green: 0.4, blue: 0.62), .black] }
        return [Color(red: 0.65, green: 0.58, blue: 0.45), Color(red: 0.22, green: 0.3, blue: 0.28)]
    }
}
