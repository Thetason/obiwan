import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // MethodChannel for on-device CREPE (CoreML)
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "obiwan.ondevice_crepe",
                                       binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler({ (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      switch call.method {
      case "analyzeWindow":
        guard let args = call.arguments as? [String: Any],
              let bytes = args["audio_bytes"] as? FlutterStandardTypedData,
              let sampleRate = args["sample_rate"] as? Double else {
          result(FlutterError(code: "BAD_ARGS", message: "Missing audio_bytes/sample_rate", details: nil))
          return
        }
        if #available(iOS 13.0, *) {
          let ok = OnDeviceCrepeRunner.shared.loadModel()
          if ok {
            let (f0, conf) = OnDeviceCrepeRunner.shared.analyzeWindow(samples: bytes.data, sampleRate: sampleRate)
            let response: [String: Any] = [
              "f0": f0,
              "confidence": conf
            ]
            result(response)
          } else {
            result(["f0": 0.0, "confidence": 0.0])
          }
        } else {
          result(["f0": 0.0, "confidence": 0.0])
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    })
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
