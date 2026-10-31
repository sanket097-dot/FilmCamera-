# FilmCamera: free Windows-first development route

## Reality check
The app is native Swift/SwiftUI and uses AVFoundation. Windows cannot run Xcode, the iOS Simulator, or compile an iOS app locally. There is no reliable Windows-only way to test real iPhone camera hardware.

## Free route to try first
Use a GitHub repository and a GitHub Actions macOS runner to compile the app in the cloud. This avoids renting a Mac, but requires setup and is not the same as having a Mac desktop.

1. Create a GitHub account.
2. Create a NEW private repository initially (make it public only if you are comfortable publishing your source code).
3. Upload the starter project's Swift files and README.
4. Add a GitHub Actions workflow that runs on `macos-latest` and uses `xcodebuild` to build for a generic iOS device.
5. Inspect build logs and fix compiler errors.
6. For a physical iPhone install, the resulting app must be properly signed. A cloud build alone does not install it.
7. A practical sideload test may use an unsigned IPA from the build, then a Windows sideloading tool such as Sideloadly to sign/install it with your Apple Account. This route has provisioning limitations, typically requires refreshing free-account installs periodically, and is not a supported substitute for App Store distribution. Verify the current tool instructions and Apple signing requirements before proceeding.

## Important limits
- GitHub-hosted macOS runner availability, free quotas and billing policies can change. Check GitHub's current Actions billing page before enabling workflows.
- Do not put Apple passwords, private keys, certificates, provisioning profiles, or API keys in source code or public repositories.
- Do not upload an IPA to unknown websites.
- Test only on your own iPhone and Apple Account.
- TestFlight/App Store distribution generally requires Apple Developer Program membership.
- A real iPhone test is essential for camera behavior, RAW capability and image quality.

## What to do now
Start with a private GitHub repository. Upload the extracted project folder. Do not try to install the ZIP directly on iPhone. The next step is to add a macOS build workflow and use the build log to correct any compiler issues.

## Product caveat
The current starter is an early scaffold. Film looks are approximate algorithms, not validated emulations; live film preview and a complete RAW/DNG development pipeline are not implemented yet. iOS does not expose a universal switch to disable all internal computational photography.
