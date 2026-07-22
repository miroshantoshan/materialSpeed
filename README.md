<p align="center">
  <img src="Resources/logo.png" alt="materialSpeed logo" width="128" />
</p>

<h1 align="center">materialSpeed</h1>

<p align="center">
  <img src="https://img.shields.io/badge/lang-Swift-purple?style=for-the-badge" alt="Swift">
  <img src="https://img.shields.io/badge/for--purple?style=for-the-badge" alt="macOS">
  <img src="https://img.shields.io/badge/lang-RU | ENG-purple?style=for-the-badge" alt="Languages">
</p>

**materialSpeed** is a minimal native speed test app for macOS.

It checks your connection speed, shows the current result in a compact interface, and keeps a short local history of recent tests.

## What It Measures

- Download speed
- Upload speed
- Ping
- Jitter

Tests use Cloudflare speed test endpoints. Results can vary depending on your network, Wi-Fi quality, VPN, provider routing, and current server load.

## Requirements

- macOS 13 Ventura or newer
- Internet connection

## Installation

1. Download [`install.command`](install.command).
2. Double-click the downloaded file.
3. Wait while the installer downloads the latest source code, builds the app, and installs it.
4. materialSpeed will open automatically when installation is complete.

Only the installer file is required. It fetches the current `main` branch from this repository, creates a local release build, installs the app to `~/Applications`, removes its temporary files, and then closes the Terminal window. The installer itself remains available and can be run again to update or reinstall the app.

If Swift is not installed, the installer opens Apple's official Command Line Tools setup and continues automatically after it finishes. If macOS asks for confirmation before opening `install.command`, right-click the file in Finder and choose **Open**.

## Usage

Open materialSpeed and press the start button. The app will measure latency first, then download speed, then upload speed.

Completed tests are saved in local history inside the app. You can open history with the clock button and clear it at any time.

English is used by default. Open settings with the gear button to switch between English and Russian.

## Privacy

materialSpeed does not require an account and does not collect personal data.

The app stores test history locally on your Mac using system app storage. Speed measurements connect to Cloudflare speed test endpoints to perform the network test.

## Manual Build From Source

The terminal installer is the recommended installation method. To run the project manually instead:

```bash
swift run
```

To create a local macOS app bundle:

```bash
./package_app.sh
open dist/materialSpeed.app
```

## License

materialSpeed is released under the MIT License.
