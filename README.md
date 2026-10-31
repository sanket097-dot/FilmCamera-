# FilmCamera — Native iOS starter

A focused native iPhone camera starter for:
1. User-selectable capture/processing behavior where iOS exposes controls.
2. Fifteen film-inspired looks applied through a Core Image rendering pipeline.

## Important hardware/API reality

This starter targets iPhone 15 (standard). It does **not** assume Apple ProRAW is available: ProRAW is a Pro-model feature. The app checks the active camera's actual RAW pixel formats at runtime and offers RAW only if the device/format supports it. Otherwise it captures the best supported processed format and clearly reports that RAW is unavailable.

Third-party apps cannot switch off every internal iPhone computational-photography stage (for example, all Smart HDR/Deep Fusion behavior). The app therefore exposes only honest controls:
- Capture format: processed or RAW when supported.
- Flash: off/on/auto.
- Exposure compensation.
- White balance lock (when supported by the active device).
- Lens selection where available.
- Film rendering after capture.

The initial implementation applies film looks to the captured image using Core Image. It is a functional foundation, not yet a laboratory-calibrated emulation of physical film stocks. Calibration requires reference scans and device/display testing.

## Open in Xcode

1. On a Mac, create a new iOS App project named `FilmCamera` using SwiftUI.
2. Set deployment target to iOS 17 or later.
3. Add all `.swift` files in the `FilmCamera` folder to the app target.
4. In the target's Info settings, add:
   - `NSCameraUsageDescription`: FilmCamera needs camera access to take photographs.
   - `NSPhotoLibraryAddUsageDescription`: FilmCamera saves photographs to your library.
5. Run on a physical iPhone. The iOS Simulator has no real camera capture.
6. Select your iPhone 15 as the run destination and trust the developer profile if prompted.

## Included

- SwiftUI camera screen and live AVFoundation preview.
- Runtime capability detection for RAW.
- Processed/RAW capture selection.
- Flash and exposure controls.
- Fifteen selectable film-inspired profiles.
- Core Image film rendering pipeline.
- Save rendered images to Photos.
- Clear separation between capture service, view model, and rendering engine.

## Current limitations / next milestones

- Film profiles are initial algorithmic approximations, not exact copies of named commercial film stocks.
- Preview is currently a live camera feed; film rendering is applied to the captured still. Next milestone: low-latency live preview rendering with AVCaptureVideoDataOutput + Metal/Core Image.
- RAW capture uses the camera's supported Bayer RAW format if exposed. DNG writing and RAW-specific rendering pipeline should be added and tested on target hardware.
- Advanced independent processing toggles are not exposed by public iOS APIs. Do not label unsupported internal processing stages as disabled.
- Add a dedicated RAW development pipeline, calibrated color transforms, lens shading/white-balance handling, and a full export settings screen before public release.
