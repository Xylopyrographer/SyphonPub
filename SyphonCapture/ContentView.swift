import SwiftUI
import ScreenCaptureKit

struct ContentView: View {
    @EnvironmentObject private var captureManager: CaptureManager
    @State private var selectedWindowID: CGWindowID? = nil

    var body: some View {
        VSplitView {
            previewPane
            controlPane
        }
        .frame(minWidth: 640, minHeight: 500)
    }

    // MARK: - Preview pane

    private var previewPane: some View {
        ZStack {
            Color.black

            if captureManager.isCapturing {
                PreviewView(layer: captureManager.previewLayer)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "play.rectangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(selectedWindowID == nil ? "Select a window below, then press Start" : "Press Start to begin capture")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(minHeight: 240)
    }

    // MARK: - Control pane (window list + toolbar)

    private var controlPane: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("SyphonPub")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await captureManager.refreshWindows() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(captureManager.isLoading || captureManager.isCapturing)

                HStack(spacing: 6) {
                    Text("FPS")
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    Picker("", selection: $captureManager.frameRate) {
                        ForEach([15, 24, 30, 60], id: \.self) { fps in
                            Text("\(fps)").tag(fps)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
                .padding(.leading, 12)
                .padding(.trailing, 12)
                .onChange(of: captureManager.frameRate) { _, _ in
                    Task { await captureManager.applyFrameRate() }
                }

                captureButton
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            // Window list
            if captureManager.isLoading {
                ProgressView("Loading windows…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if captureManager.permissionDenied {
                permissionDeniedView
            } else if captureManager.availableWindows.isEmpty {
                ContentUnavailableView(
                    "No Windows Found",
                    systemImage: "macwindow",
                    description: Text("Click Refresh to scan for open windows.")
                )
            } else {
                windowList
            }
        }
        .frame(minHeight: 180)
    }

    // MARK: - Subviews

    private var captureButton: some View {
        Button {
            Task {
                if captureManager.isCapturing {
                    await captureManager.stopCapture()
                } else {
                    await captureManager.startCapture()
                }
            }
        } label: {
            Label(
                captureManager.isCapturing ? "Stop" : "Start",
                systemImage: captureManager.isCapturing ? "stop.fill" : "play.fill"
            )
        }
        .buttonStyle(.borderedProminent)
        .tint(captureManager.isCapturing ? .red : .accentColor)
        .disabled(selectedWindowID == nil && !captureManager.isCapturing)
    }

    private var windowList: some View {
        List(captureManager.availableWindows, id: \.windowID, selection: $selectedWindowID) { window in
            WindowRow(window: window)
        }
        .onChange(of: selectedWindowID) { _, newValue in
            Task { @MainActor in
                captureManager.selectedWindowID = newValue
            }
        }
        .disabled(captureManager.isCapturing)
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Screen Recording Permission Required")
                .font(.headline)
            Text("Open System Settings → Privacy & Security → Screen & System Audio Recording and enable SyphonPub.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if let error = captureManager.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            HStack(spacing: 12) {
                Button("Open Privacy Settings") {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
                    )
                }
                Button("Try Again") {
                    Task { await captureManager.refreshWindows() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Window Row

struct WindowRow: View {
    let window: SCWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(window.owningApplication?.applicationName ?? "Unknown App")
                .font(.subheadline)
                .fontWeight(.medium)
            Text(window.title ?? "Untitled")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ContentView()
}
