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
    #if DEBUG
    // 시뮬레이터 화면 확인용: `xcrun simctl launch <기기> com.yongmin.ghostmanor -SHOT living/1`
    // 실행 인자를 Dart 로 넘긴다(lib/core/debug_shot.dart). 정식 빌드엔 없다.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DebugShot") {
      let channel = FlutterMethodChannel(name: "ghostmanor/debug", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        if call.method == "home" { return result(NSHomeDirectory()) }
        guard call.method == "shot" else { return result(nil) }
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-SHOT"), i + 1 < args.count { return result(args[i + 1]) }
        result(nil)
      }
    }
    #endif
  }
}
