import SwiftUI
import ScreenCaptureKit

struct MenuBarMenuView: View {
    @EnvironmentObject private var captureManager: CaptureManager

    var body: some View {
        // Status
        if captureManager.isCapturing {
            let appName = captureManager.selectedWindow?.owningApplication?.applicationName ?? "Unknown"
            Text("Capturing: \(appName)")
            Text("\(captureManager.frameRate) fps")
        } else {
            Text("Not Capturing")
        }

        Divider()

        // Source selection submenu
        Menu("Source: \(selectedSourceLabel)") {
            if captureManager.availableWindows.isEmpty {
                Text("No sources — click Refresh")
            } else {
                ForEach(captureManager.availableWindows, id: \.windowID) { window in
                    Button(windowDisplayName(window)) {
                        captureManager.selectedWindowID = window.windowID
                    }
                    .disabled(captureManager.isCapturing)
                }
            }
        }

        // Frame rate submenu
        Menu("Frame Rate: \(captureManager.frameRate) fps") {
            ForEach([15, 24, 30, 60], id: \.self) { fps in
                Button("\(fps) fps") {
                    captureManager.frameRate = fps
                    Task { await captureManager.applyFrameRate() }
                }
            }
        }

        Divider()

        // Start / Stop
        if captureManager.isCapturing {
            Button("Stop Capture") {
                Task { await captureManager.stopCapture() }
            }
        } else {
            Button("Start Capture") {
                Task { await captureManager.startCapture() }
            }
            .disabled(captureManager.selectedWindowID == nil)
        }

        Divider()

        Button("Refresh Sources") {
            Task { await captureManager.refreshWindows() }
        }
        .disabled(captureManager.isLoading || captureManager.isCapturing)

        Button("Show Window") {
            NSApp.activate(ignoringOtherApps: true)
        }

        Divider()

        Button("About SyphonPub") {
            showAboutPanel()
        }

        Button("Quit SyphonPub") {
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - Helpers

    private var selectedSourceLabel: String {
        guard let window = captureManager.selectedWindow else { return "None" }
        return window.owningApplication?.applicationName ?? "Unknown"
    }

    private func windowDisplayName(_ window: SCWindow) -> String {
        let app = window.owningApplication?.applicationName ?? "Unknown"
        if let title = window.title, !title.isEmpty, title != app {
            return "\(app) — \(title)"
        }
        return app
    }
}
