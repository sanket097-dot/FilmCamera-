# Build FilmCamera from Windows without renting a Mac

## What this does
GitHub Actions uses a hosted macOS runner to compile the Swift app and creates an **unsigned IPA**. You then use a Windows sideloading utility to sign/install it with your Apple Account. This is a development/testing route, not App Store distribution.

## Part A — create a GitHub repository
1. Go to https://github.com and create a free account or sign in.
2. Click **New repository**.
3. Name it `FilmCamera`.
4. Choose **Public** if you want GitHub's standard public-repository runner allowance. This makes your source code publicly visible. If you want private source, check your account's included Actions minutes and billing first.
5. Create the repository.

## Part B — upload this project
1. Extract the ZIP on Windows.
2. Open the extracted `FilmCameraStarter` folder.
3. On GitHub, choose **Add file → Upload files**.
4. Upload the CONTENTS of the folder, including:
   - `.github/workflows/ios-build.yml`
   - `FilmCamera/` folder
   - `project.yml`
   - README and guide files
5. Make sure `.github/workflows/ios-build.yml` is uploaded at that exact path.
6. Commit the files to the `main` branch.

Tip: Windows/File Explorer can hide folders beginning with a dot. If `.github` is hidden, enable **View → Show → Hidden items**, or upload the repository using GitHub Desktop.

## Part C — run the cloud Mac build
1. Open your repository on GitHub.
2. Click **Actions**.
3. Select **Build FilmCamera for iPhone**.
4. Click **Run workflow → Run workflow** if it has not started automatically.
5. Open the running job and watch the logs.
6. If it succeeds, scroll to **Artifacts** at the bottom.
7. Download `FilmCamera-unsigned-ipa`.
8. Extract the downloaded artifact ZIP to get `FilmCamera-unsigned.ipa`.

If the build fails, copy the first actual Swift/Xcode error from the log and share it. Do not share Apple passwords or private credentials.

## Part D — install on iPhone using Windows
1. Download Sideloadly only from https://sideloadly.io/.
2. Follow its current Windows setup guide. It may require Apple's Windows device components/iTunes and iCloud from Apple's website rather than Microsoft Store packages.
3. Connect your iPhone 15 by USB and tap **Trust This Computer** if prompted.
4. Open Sideloadly and select your iPhone.
5. Drag `FilmCamera-unsigned.ipa` into Sideloadly.
6. Enter your Apple Account details only in the official Sideloadly application if you decide to use it. Consider using a separate Apple Account for development testing and enable two-factor authentication.
7. Start sideloading and follow the iPhone prompts. On iOS 16 or later, Developer Mode may need to be enabled under Settings → Privacy & Security → Developer Mode.
8. Launch FilmCamera and grant camera and Photos permissions.

Free-account sideloading typically expires after 7 days and must be refreshed. See Sideloadly's current FAQ for details.

## Privacy and security
- Public GitHub repositories expose all committed source code. Do not upload personal photos, secrets, signing certificates, API keys or passwords.
- Never put Apple credentials in GitHub Actions YAML or repository files.
- Only download sideloading tools from their official websites.
- If you are uncomfortable entering credentials into a third-party signing utility, stop and use Apple's official Xcode signing route on a Mac instead.

## Troubleshooting
- **Workflow not visible:** confirm `.github/workflows/ios-build.yml` is on the `main` branch.
- **Build fails:** open the Actions log and copy the first compiler error, not the final generic failure line.
- **IPA installs but app won't open:** check Developer Mode, device trust, signing/provisioning and iOS compatibility.
- **Camera black screen:** check iOS Settings → Privacy & Security → Camera and confirm permission.
- **RAW option unavailable:** the app checks actual device capabilities; it does not force unsupported RAW capture.

## Current starter scope
This is an early functional scaffold. It has a live AVFoundation preview, basic capture, exposure control, a set of 15 initial film-inspired looks and post-capture Core Image rendering. It does not yet provide a live film-rendered viewfinder or validated, scientifically exact film-stock emulation.
