# SyphonPub

A lightweight native macOS utility that captures any application window and publishes it as a real-time [Syphon](https://syphon.info) video stream.

Use it to feed a browser window, presentation, or any other app directly into [ProPresenter](https://renewedvision.com/propresenter/), [Resolume](https://resolume.com), [VDMX](https://vidvox.net), or any other Syphon-compatible application.

SyphonPub is a modern, open-source implementation built from scratch using current Apple frameworks, inspired by [Syphoner](https://www.sigmasix.ch/syphoner/) by SIGMASIX.

---

## Requirements

- macOS 14.6 (Sonoma) or later

---

## Installation

Download the latest release from the [GitHub Releases](https://github.com/Xylopyrographer/SyphonPub/releases) page.

### First Launch — Gatekeeper

macOS will block unsigned apps on first launch. To open SyphonPub:

1. In Finder, right-click (or Control-click) `SyphonPub.app` and choose **Open**.
2. A dialog will appear warning that the app is from an unidentified developer. Click **Open**.

You only need to do this once. After the first launch, macOS will remember your choice.

### First Launch — Screen Recording Permission

macOS requires you to grant Screen Recording permission before SyphonPub can capture windows.

1. Launch the app and click **Refresh**.
2. A system dialog will appear. Click **Open System Settings**.
3. If SyphonPub is not listed, click **+** and navigate to `SyphonPub.app` to add it manually, then toggle it on.
4. Click **Quit Now**, then relaunch the app.

## Build from Source

1. Clone the repository, including the Syphon Framework submodule:

   ```
   git clone --recurse-submodules https://github.com/Xylopyrographer/SyphonPub.git
   ```

2. Open `SyphonCapture.xcodeproj` in Xcode.

3. Build and run with **Product > Run** (or `Cmd+R`).

4. The project was built using Xcode 26.4.1.



### First Launch — Screen Recording Permission (Source Builds)

Follow the same Screen Recording permission steps as above.

> On macOS 15 (Sequoia) and later, screen recording permission is tied to the specific app binary. You will need to re-grant permission each time you build a new version from source. This limitation does not apply to signed and notarized release builds.

---

## Usage

1. **Refresh Sources** — click Refresh (or use the menu bar icon) to populate the window list.
2. **Select a window** — choose any open window from the list.
3. **Set frame rate** — use the FPS control to select 15, 24, 30, or 60 fps.
4. **Start** — click Start to begin capture. The in-app preview updates in real time.
5. **Connect in your Syphon client** — SyphonPub appears as a source named **SyphonPub** in any Syphon-compatible app.

The menu bar icon (looks like a "Record" button) mirrors all controls, so the main window does not need to stay open once capture is running.

---

## License

SyphonPub is released under the [MIT License](LICENSE).

It incorporates the [Syphon Framework](https://github.com/Syphon/Syphon-Framework), which is distributed under the BSD 2-Clause License. See [LICENSE](LICENSE) for full details.
