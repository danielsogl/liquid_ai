import Flutter
import UIKit
import LeapSDK

/// Flutter plugin for Liquid AI with LEAP SDK integration.
public class LiquidAiPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "liquid_ai",
      binaryMessenger: registrar.messenger()
    )
    let instance = LiquidAiPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
