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
    case "pickDownloadsFolder":
      // Downloads live in <picked>/Diegema; the sandbox only lets the app
      // write there once the user has chosen the folder.
      let home = URL(fileURLWithPath: String(cString: getpwuid(getuid()).pointee.pw_dir))
      let audiobooks = home.appendingPathComponent("Audiobooks", isDirectory: true)
      let panel = NSOpenPanel()
      panel.canChooseDirectories = true
      panel.canChooseFiles = false
      panel.canCreateDirectories = true
      panel.allowsMultipleSelection = false
      panel.prompt = "Save Downloads Here"
      panel.message = "Choose where Diegema saves downloaded audiobooks. "
        + "A Diegema folder is made inside it (for example Audiobooks/Diegema)."
      panel.directoryURL =
        FileManager.default.fileExists(atPath: audiobooks.path) ? audiobooks : home
      guard panel.runModal() == .OK, let picked = panel.url else { return result(nil) }
      let root = picked.lastPathComponent == "Diegema"
        ? picked : picked.appendingPathComponent("Diegema", isDirectory: true)
      do {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let data = try root.bookmarkData(
          options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        let path = root.standardizedFileURL.path
        if open[path] == nil, root.startAccessingSecurityScopedResource() {
          open[path] = root
        }
        result(["path": path, "bookmark": data.base64EncodedString()])
      } catch {
        result(FlutterError(
          code: "pick", message: error.localizedDescription, details: nil))
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
