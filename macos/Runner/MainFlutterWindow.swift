import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    FolderAccessChannel.register(
      messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

/// Native half of `lib/services/folder_access.dart`: security-scoped
/// bookmarks, so a library folder picked in one run can be read in the next
/// without the sandbox asking again. Read-only scope: Diegema never writes
/// inside a library folder.
final class FolderAccessChannel {
  private static var instance: FolderAccessChannel?
  private let channel: FlutterMethodChannel
  /// Folders whose access is started, by path. Held for the whole run
  /// because chapters are read from them during playback.
  private var open: [String: URL] = [:]

  private init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "diegema/folder_access", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  static func register(messenger: FlutterBinaryMessenger) {
    instance = FolderAccessChannel(messenger: messenger)
  }

  private func handle(_ call: FlutterMethodCall, result: FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "bookmark":
      guard let path = args["path"] as? String else {
        return result(FlutterError(code: "args", message: "path", details: nil))
      }
      do {
        let data = try URL(fileURLWithPath: path, isDirectory: true).bookmarkData(
          options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
          includingResourceValuesForKeys: nil, relativeTo: nil)
        result(data.base64EncodedString())
      } catch {
        result(FlutterError(
          code: "bookmark", message: error.localizedDescription, details: nil))
      }
    case "open":
      guard let encoded = args["bookmark"] as? String,
        let data = Data(base64Encoded: encoded)
      else {
        return result(FlutterError(code: "args", message: "bookmark", details: nil))
      }
      do {
        var stale = false
        let url = try URL(
          resolvingBookmarkData: data, options: [.withSecurityScope],
          relativeTo: nil, bookmarkDataIsStale: &stale)
        let path = url.standardizedFileURL.path
        if open[path] == nil {
          guard url.startAccessingSecurityScopedResource() else {
            return result(nil)
          }
          open[path] = url
        }
        result(["path": path, "stale": stale])
      } catch {
        // Deleted, or on a drive that isn't mounted: not an error to report.
        result(nil)
      }
    case "close":
      if let path = args["path"] as? String, let url = open.removeValue(forKey: path) {
        url.stopAccessingSecurityScopedResource()
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
