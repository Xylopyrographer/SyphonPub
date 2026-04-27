import Foundation
import Combine
import AppKit
import ScreenCaptureKit
import AVFoundation
@preconcurrency import CoreMedia
import CoreVideo
import Metal
import Syphon

/// Window titles that belong to system chrome rather than real app content.
private let systemWindowTitles: Set<String> = [
    "Menubar", "Menu Bar", "Dock", "Display Backstop",
    "Control Center", "Notification Center", "Desktop", "Backstop Menubar",
]

enum CaptureSource: Hashable {
    case window(CGWindowID)
    case display(CGDirectDisplayID)
}

@MainActor
class CaptureManager: NSObject, ObservableObject {

    // MARK: - Published state

    @Published var availableWindows: [SCWindow] = []
    @Published var availableDisplays: [SCDisplay] = []
    @Published var selectedSource: CaptureSource? = nil
    @Published var isLoading = false
    @Published var isCapturing = false
    @Published var permissionDenied = false
    @Published var lastError: String? = nil
    @Published var frameRate: Int = 60

    /// Layer that receives captured frames for live preview.
    /// AVSampleBufferVideoRenderer is thread-safe — enqueue directly from callback queue.
    nonisolated(unsafe) let previewLayer = AVSampleBufferDisplayLayer()

    // MARK: - Private

    private var stream: SCStream?

    // Metal device is immutable after init — safe to use from any thread.
    private let metalDevice: MTLDevice

    // Command queue and Syphon server are accessed from the SCStreamOutput callback
    // (background queue). Both are internally thread-safe.
    nonisolated(unsafe) private var commandQueue: MTLCommandQueue
    nonisolated(unsafe) private var syphonServer: SyphonMetalServer?

    // MARK: - Init

    override init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            fatalError("Metal is not supported on this device")
        }
        metalDevice = device
        commandQueue = queue
        super.init()
    }

    // MARK: - Source enumeration

    func refreshSources() async {
        isLoading = true
        permissionDenied = false
        lastError = nil
        defer { isLoading = false }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            availableDisplays = content.displays.sorted { $0.displayID < $1.displayID }
            availableWindows = content.windows
                .filter { isUserWindow($0) }
                .sorted {
                    let a = $0.owningApplication?.applicationName ?? ""
                    let b = $1.owningApplication?.applicationName ?? ""
                    return a.localizedCompare(b) == .orderedAscending
                }
        } catch {
            permissionDenied = true
            lastError = error.localizedDescription
            availableDisplays = []
            availableWindows = []
        }
    }

    /// Returns the human-readable name for a display, matched via NSScreen.localizedName.
    func displayName(for display: SCDisplay) -> String {
        let screen = NSScreen.screens.first { screen in
            let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            return num.map { CGDirectDisplayID($0.uint32Value) == display.displayID } ?? false
        }
        return screen?.localizedName ?? "Display \(display.displayID)"
    }

    // MARK: - Capture

    func startCapture() async {
        guard let source = selectedSource else { return }

        let filter: SCContentFilter
        let config: SCStreamConfiguration
        let serverName: String

        switch source {
        case .window(let id):
            guard let window = availableWindows.first(where: { $0.windowID == id }) else { return }
            filter = SCContentFilter(desktopIndependentWindow: window)
            config = makeStreamConfiguration(for: window)
            serverName = "SyphonPub — \(window.owningApplication?.applicationName ?? "Window")"
        case .display(let id):
            guard let display = availableDisplays.first(where: { $0.displayID == id }) else { return }
            filter = SCContentFilter(display: display, excludingWindows: [])
            config = makeStreamConfiguration(for: display)
            serverName = "SyphonPub — \(displayName(for: display))"
        }

        syphonServer = SyphonMetalServer(name: serverName, device: metalDevice, options: nil)

        do {
            let stream = SCStream(filter: filter, configuration: config, delegate: self)
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
            try await stream.startCapture()
            self.stream = stream
            self.isCapturing = true
        } catch {
            lastError = error.localizedDescription
            syphonServer?.stop()
            syphonServer = nil
        }
    }

    func stopCapture() async {
        guard let stream else { return }
        do {
            try await stream.stopCapture()
        } catch {
            lastError = error.localizedDescription
        }
        self.stream = nil
        self.isCapturing = false
        syphonServer?.stop()
        syphonServer = nil
        await previewLayer.sampleBufferRenderer.flush(removingDisplayedImage: true)
    }

    func applyFrameRate() async {
        guard let stream, let source = selectedSource else { return }
        let config: SCStreamConfiguration
        switch source {
        case .window(let id):
            guard let window = availableWindows.first(where: { $0.windowID == id }) else { return }
            config = makeStreamConfiguration(for: window)
        case .display(let id):
            guard let display = availableDisplays.first(where: { $0.displayID == id }) else { return }
            config = makeStreamConfiguration(for: display)
        }
        do {
            try await stream.updateConfiguration(config)
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Private helpers

    private func makeStreamConfiguration(for window: SCWindow) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        // Multiply by the display scale factor so we capture native pixels on Retina
        // displays. Without this, the stream is half-resolution and appears fuzzy in
        // Syphon clients (ProPresenter, OBS, etc.).
        let scale = displayScaleFactor(for: window)
        config.width = Int(window.frame.width * scale)
        config.height = Int(window.frame.height * scale)
        config.minimumFrameInterval = CMTime(value: 1, timescale: Int32(frameRate))
        config.queueDepth = 3
        config.showsCursor = false
        // Explicit BGRA so the Metal texture format is always known.
        config.pixelFormat = kCVPixelFormatType_32BGRA
        return config
    }

    private func makeStreamConfiguration(for display: SCDisplay) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        // SCDisplay dimensions are already in physical pixels — no scale factor needed.
        config.width = display.width
        config.height = display.height
        config.minimumFrameInterval = CMTime(value: 1, timescale: Int32(frameRate))
        config.queueDepth = 3
        config.showsCursor = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        return config
    }

    /// Returns the backing scale factor of the display containing the window.
    /// SCWindow.frame uses top-left origin (CoreGraphics); NSScreen.frame uses
    /// bottom-left origin (AppKit) — Y must be flipped before comparing.
    private func displayScaleFactor(for window: SCWindow) -> CGFloat {
        guard let primaryScreen = NSScreen.screens.first else {
            return NSScreen.main?.backingScaleFactor ?? 2.0
        }
        let windowCenter = CGPoint(x: window.frame.midX, y: window.frame.midY)
        let flippedCenter = CGPoint(x: windowCenter.x,
                                    y: primaryScreen.frame.height - windowCenter.y)
        let screen = NSScreen.screens.first { $0.frame.contains(flippedCenter) }
                     ?? NSScreen.main
        return screen?.backingScaleFactor ?? 2.0
    }

    private func isUserWindow(_ window: SCWindow) -> Bool {
        guard let app = window.owningApplication else { return false }
        guard let title = window.title, !title.isEmpty else { return false }

        // Only show windows whose owning process is — or is a helper of — a regular
        // .app bundle (one that appears in the Dock / App Switcher).
        // Electron apps (VS Code, Slack, etc.) render in a helper subprocess whose
        // bundle ID is a child of the main app, e.g. com.microsoft.VSCode.helper.renderer.
        let ownerID = app.bundleIdentifier
        let isRegularApp = NSWorkspace.shared.runningApplications.contains {
            guard $0.activationPolicy == .regular,
                  let bid = $0.bundleIdentifier else { return false }
            return ownerID == bid || ownerID.hasPrefix(bid + ".")
        }
        guard isRegularApp else { return false }

        if systemWindowTitles.contains(title) { return false }
        if title.hasSuffix("Backdrop") || title.hasSuffix("Backstop") { return false }
        if window.frame.width < 100 || window.frame.height < 100 { return false }

        return true
    }
}

// MARK: - SCStreamOutput

extension CaptureManager: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .screen else { return }

        // Live preview — AVSampleBufferVideoRenderer is thread-safe.
        if previewLayer.sampleBufferRenderer.status == .failed {
            previewLayer.sampleBufferRenderer.flush()
        }
        previewLayer.sampleBufferRenderer.enqueue(sampleBuffer)

        // Syphon publishing — zero-copy: IOSurface → MTLTexture → SyphonMetalServer.
        guard let server = syphonServer,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let ioSurface = CVPixelBufferGetIOSurface(imageBuffer)?.takeUnretainedValue()
        else { return }

        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .managed

        guard let texture = metalDevice.makeTexture(
            descriptor: descriptor,
            iosurface: ioSurface,
            plane: 0
        ),
        let commandBuffer = commandQueue.makeCommandBuffer()
        else { return }

        server.publishFrameTexture(
            texture,
            on: commandBuffer,
            imageRegion: NSRect(x: 0, y: 0, width: width, height: height),
            flipped: true
        )
        commandBuffer.commit()
    }
}

// MARK: - SCStreamDelegate

extension CaptureManager: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.isCapturing = false
            self?.stream = nil
            self?.syphonServer?.stop()
            self?.syphonServer = nil
        }
    }
}
