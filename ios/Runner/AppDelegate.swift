import Flutter
import UIKit

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

    let channel = FlutterMethodChannel(
      name: "id.ucapkas.app/file_saver",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "savePdf":
        guard
          let args = call.arguments as? [String: Any],
          let typedBytes = args["bytes"] as? FlutterStandardTypedData
        else {
          result(FlutterError(code: "INVALID_ARGS", message: "PDF bytes kosong", details: nil))
          return
        }
        let rawName = (args["filename"] as? String) ?? "invoice.pdf"
        let safeName = rawName.replacingOccurrences(of: "/", with: "-")
        let finalName = safeName.lowercased().hasSuffix(".pdf") ? safeName : "\(safeName).pdf"
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileUrl = docsDir.appendingPathComponent(finalName)
        do {
          try typedBytes.data.write(to: fileUrl, options: .atomic)
          result([
            "filePath": fileUrl.path,
            "displayLocation": "Files / On My iPhone / UcapKas / \(finalName)",
            "contentUri": fileUrl.absoluteString
          ])
        } catch {
          result(FlutterError(code: "SAVE_PDF_ERROR", message: error.localizedDescription, details: nil))
        }
      case "openPdf", "sharePdf":
        guard
          let args = call.arguments as? [String: Any],
          let filePath = args["filePath"] as? String
        else {
          result(false)
          return
        }
        let fileUrl = URL(fileURLWithPath: filePath)
        var items: [Any] = [fileUrl]
        if let text = args["text"] as? String, !text.isEmpty {
          items.append(text)
        }
        DispatchQueue.main.async {
          guard let rootVC = self?.window?.rootViewController else {
            result(false)
            return
          }
          let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
          rootVC.present(activityVC, animated: true)
          result(true)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
