import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 检测当前设备是否能提供 Google 登录所需的 Google Play services。
///
/// 只在 Android 上调用原生 `GoogleApiAvailability`；其他平台直接返回 false，
/// 因为当前产品策略只在 Android 暴露 Google 登录入口。
abstract class GoogleServicesAvailability {
  Future<bool> isAvailable();
}

class MethodChannelGoogleServicesAvailability
    implements GoogleServicesAvailability {
  const MethodChannelGoogleServicesAvailability();

  static const _channel = MethodChannel('top.echo-loop/google_services');

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>(
        'isGooglePlayServicesAvailable',
      );
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
