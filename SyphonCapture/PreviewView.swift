import SwiftUI
import AVFoundation
import AppKit

/// SwiftUI wrapper around AVSampleBufferDisplayLayer for live frame preview.
struct PreviewView: NSViewRepresentable {
    let layer: AVSampleBufferDisplayLayer

    func makeNSView(context: Context) -> PreviewNSView {
        PreviewNSView(displayLayer: layer)
    }

    func updateNSView(_ nsView: PreviewNSView, context: Context) {}
}

/// Custom NSView that hosts an AVSampleBufferDisplayLayer as its backing layer.
final class PreviewNSView: NSView {
    private let displayLayer: AVSampleBufferDisplayLayer

    init(displayLayer: AVSampleBufferDisplayLayer) {
        self.displayLayer = displayLayer
        super.init(frame: .zero)
        wantsLayer = true
        layer?.addSublayer(displayLayer)
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        // Keep the display layer filling the view
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer.frame = bounds
        CATransaction.commit()
    }
}
