# Testing FilmCamera when you only have Windows

## The key limitation
This project is a native SwiftUI / AVFoundation iOS app. It cannot be compiled or run as an iPhone app directly on Windows. The iOS Simulator and Xcode require macOS.

## Recommended route: use a cloud Mac
1. Create an account with a hosted Mac provider or a CI service that offers macOS runners.
2. Use a Mac session/runner with a current compatible version of Xcode.
3. Upload or clone this project.
4. Open/create the iOS app project in Xcode and add the Swift files to the app target.
5. Add these Info.plist privacy descriptions:
   - NSCameraUsageDescription
   - NSPhotoLibraryAddUsageDescription
6. Connect your Apple Developer account in Xcode.
7. Select a physical iPhone destination and build/run, or archive and distribute through TestFlight.
8. On your iPhone, install the TestFlight app, accept the invitation, and install the build.

## Signing options
- For repeated device testing and TestFlight distribution, an Apple Developer Program membership is generally needed.
- A free Apple Account / Personal Team can be used for limited development signing from Xcode, subject to Apple's restrictions and provisioning expiry. Availability and limits can change; check Apple's current documentation.
- TestFlight builds must be signed and uploaded through Apple's supported distribution process.

## What will not work
- You cannot install the Swift source code or ZIP directly on iPhone.
- Windows does not run Xcode or the iOS Simulator.
- Browser-based iPhone simulators cannot accurately test camera hardware, RAW capture, or AVFoundation behavior.

## Practical test plan
First test on a real iPhone 15:
1. Camera permission prompt appears.
2. Rear camera preview starts.
3. Capture a standard processed photo.
4. Select each of the 15 looks and capture test scenes.
5. Confirm the processed photo saves to Photos.
6. Check whether RAW is actually reported as available. Do not assume it is.
7. Test exposure compensation at -2, 0 and +2 EV.
8. Test bright daylight, indoor mixed lighting, skin tones, night scenes and high-contrast scenes.
9. Compare rendered output against the original and check for clipping, color shifts and excessive grain.

## Important product limitation
Third-party apps cannot disable every internal iPhone computational-photography stage. This app can only expose controls available through public iOS APIs and apply its own rendering pipeline. The current starter applies film looks after capture; it does not yet render the look live in the viewfinder.
