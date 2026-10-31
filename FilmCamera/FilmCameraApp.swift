import SwiftUI

@main
struct FilmCameraApp: App {
    @StateObject private var camera = CameraViewModel()

    var body: some Scene {
        WindowGroup {
            CameraScreen()
                .environmentObject(camera)
                .preferredColorScheme(.dark)
        }
    }
}
