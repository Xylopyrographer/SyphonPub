import SwiftUI

@main
struct SyphonCaptureApp: App {
    @StateObject private var captureManager = CaptureManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(captureManager)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About SyphonPub") {
                    showAboutPanel()
                }
            }
        }

        MenuBarExtra {
            MenuBarMenuView()
                .environmentObject(captureManager)
        } label: {
            Image(systemName: captureManager.isCapturing ? "record.circle.fill" : "record.circle")
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Shows the standard macOS About panel with copyright and GitHub link.
func showAboutPanel() {
    NSApp.activate(ignoringOtherApps: true)

    let centered = NSMutableParagraphStyle()
    centered.alignment = .center

    let credits = NSMutableAttributedString(
        string: "Copyright © 2026 Xylopyrographer\n\n",
        attributes: [.paragraphStyle: centered]
    )
    let repoURL = URL(string: "https://github.com/Xylopyrographer/SyphonPub")!
    credits.append(NSAttributedString(
        string: "github.com/Xylopyrographer/SyphonPub",
        attributes: [.link: repoURL, .paragraphStyle: centered]
    ))

    NSApplication.shared.orderFrontStandardAboutPanel(options: [
        .credits: credits
    ])
}
