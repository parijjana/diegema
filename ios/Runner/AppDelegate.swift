import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FolderAccessChannel") {
      FolderAccessChannel.register(messenger: registrar.messenger())
    }
  }
}

/// Native half of `lib/services/folder_access.dart` on iOS. The iOS twin of
/// the one in `macos/Runner/MainFlutterWindow.swift`, with one addition:
/// `pickFolder`. file_picker hands back only a path and never opens the
/// folder's security scope, so on iOS Dart could neither read the folder nor
/// bookmark it; this picker keeps the scope open and bookmarks it at once.
final class FolderAccessChannel: NSObject, UIDocumentPickerDelegate {
  private static var instance: FolderAccessChannel?
  private let channel: FlutterMethodChannel
  /// Folders whose access is started, by path. Held for the whole run
  /// because chapters are read from them during playback.
  private var open: [String: URL] = [:]
  private var pendingPick: FlutterResult?

  private init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "diegema/folder_access", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  static func register(messenger: FlutterBinaryMessenger) {
    instance = FolderAccessChannel(messenger: messenger)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "pickFolder":
      pickFolder(result: result)
    case "bookmark":
      guard let path = args["path"] as? String else {
        return result(FlutterError(code: "args", message: "path", details: nil))
      }
      let url = open[path] ?? URL(fileURLWithPath: path, isDirectory: true)
      do {
        result(try bookmark(url))
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
          resolvingBookmarkData: data, options: [], relativeTo: nil,
          bookmarkDataIsStale: &stale)
        guard let path = start(url) else { return result(nil) }
        result(["path": path, "stale": stale])
      } catch {
        // Deleted, or in a provider that's gone: not an error to report.
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

  private func bookmark(_ url: URL) throws -> String {
    try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
      .base64EncodedString()
  }

  /// Starts access (once per path) and returns the path Dart should use.
  private func start(_ url: URL) -> String? {
    let path = url.standardizedFileURL.path
    if open[path] == nil {
      guard url.startAccessingSecurityScopedResource() else { return nil }
      open[path] = url
    }
    return path
  }

  private func pickFolder(result: @escaping FlutterResult) {
    guard pendingPick == nil else {
      return result(FlutterError(code: "busy", message: "picker open", details: nil))
    }
    let root = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
      .first
    guard var top = root else {
      return result(FlutterError(code: "ui", message: "no window", details: nil))
    }
    while let presented = top.presentedViewController { top = presented }
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
    picker.delegate = self
    picker.allowsMultipleSelection = false
    pendingPick = result
    top.present(picker, animated: true)
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
  ) {
    guard let result = pendingPick else { return }
    pendingPick = nil
    guard let url = urls.first, let path = start(url) else { return result(nil) }
    do {
      result(["path": path, "bookmark": try bookmark(url)])
    } catch {
      // Readable this run even without a bookmark; it just won't survive
      // a relaunch.
      result(["path": path])
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingPick?(nil)
    pendingPick = nil
  }
}
