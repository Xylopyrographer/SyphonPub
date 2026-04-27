import SwiftUI
import ScreenCaptureKit

struct MenuBarMenuView: View {
    @EnvironmentObject private var captureManager: CaptureManager

    var body: some View {
        // Status
        if captureManager.isCapturing {
            Text("Capturing: \(activeSourceLabel)")
            Text("\(captureManager.frameRate) fps")
        } else {
            Text("Not Capturing")
        }

        Divider()

        // Source selection submenu
        Menu("Source: \(selectedSourceLabel)") {
            if captureManager.availableDisplays.isEmpty && captureManager.availableWindows.isEmpty {
                Text("No sources — click Refresh")
            } else {
                if !captureManager.availableDisplays.isEmpty {
                    Section("Displays") {
                        ForEach(captureManager.availableDisplays, id: \.displayID) { display in
                            Button(captureManager.displayName(for: display)) {
                                captureManager.selectedSource = .display(display.displayID)
                            }
                            .disabled(captureManager.isCapturing)
                        }
                    }
                }
                if !captureManager.availableWindows.isEmpty {
                    Section("Windows") {
                        ForEach(captureManager.availableWindows, id: \.windowID) { window in
                            Button(windowDisplayName(window)) {
                                captureManager.selectedSource = .window(window.windowID)
                            }
                            .disabled(captureManager.isCapturing)
                        }
                    }
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
            .disabled(captureManager.selectedSource == nil)
        }

        Divider()

        Button("Refresh Sources") {
            Task { await captureManager.refreshSources() }
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
        guard let source = captureManager.selectedSource else { return "None" }
        switch source {
        case .window(let id):
            return captureManager.availableWindows.first { $0.windowID == id }?
                .owningApplication?.applicationName ?? "Unknown"
        case .display(let id):
            guard let display = captureManager.availableDisplays.first(where: { $0.displayID == id }) else {
                return "Unknown"
            }
            return captureManager.displayName(for: display)
        }
    }

    private var activeSourceLabel: String {
        // Same logic as selectedSourceLabel — used while capturing.
        selectedSourceLabel
    }

    private func windowDisplayName(_ window: SCWindow) -> String {
        let app = window.owningApplication?.applicationName ?? "Unknown"
        if let title = window.title, !title.isEmpty, title != app {
            return "\(app) — \(title)"
        }
        return app
    }
}
