import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  // Must be retained for the lifetime of the window — handler uses [weak self]
  private var recordingBridge: RecordingBridge?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Register platform channels before plugins so they're ready on first frame.
    let _ = OutlookBridge(messenger: flutterViewController.engine.binaryMessenger)
    recordingBridge = RecordingBridge(messenger: flutterViewController.engine.binaryMessenger)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
