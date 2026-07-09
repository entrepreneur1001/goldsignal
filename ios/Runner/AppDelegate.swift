import Flutter
import UIKit
import home_widget
import workmanager

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// Must match Dart `widgetBackgroundTaskName` and Info.plist BGTask ids.
  static let widgetRefreshTaskId = "goldsignal.widgetPriceRefresh"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Allow iOS background fetch / BGAppRefresh (workmanager).
    UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(60 * 15))

    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.registerTask(withIdentifier: AppDelegate.widgetRefreshTaskId)

    if #available(iOS 17, *) {
      HomeWidgetBackgroundWorker.setPluginRegistrantCallback { registry in
        GeneratedPluginRegistrant.register(with: registry)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
