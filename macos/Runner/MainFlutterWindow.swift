import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var widgetChannel: PlannerWidgetChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.minSize = NSSize(width: 800, height: 560)
    if windowFrame.width < 1100 || windowFrame.height < 720 {
      self.setFrame(NSRect(origin: windowFrame.origin, size: NSSize(width: 1200, height: 800)), display: true)
    } else {
      self.setFrame(windowFrame, display: true)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)
    widgetChannel = PlannerWidgetChannel(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}
