/// PostHog 上报通道
///
/// 直接通过 HTTP 上报，不依赖 GMS，中国大陆和境外均可使用。
///
/// **初始化路径**（iOS / macOS）：
/// - 原生侧：通过 `Info.plist` 配 `com.posthog.posthog.API_KEY` 等 meta-data，
///   插件在 `register(with:)` 阶段（即 `applicationDidFinishLaunching` 内）自动初始化，
///   确保能捕获 `Application Opened` / `Application Backgrounded` 等生命周期事件。
/// - Dart 侧：此处 `Posthog().setup(config)` 注入 Session Replay 等运行时配置。
///   SDK 二次 setup 是幂等的（仅更新配置，不重置事件队列）。
///
/// Android 无需原生 meta-data（生命周期事件已稳定上报）。
library;

import 'package:posthog_flutter/posthog_flutter.dart';

import '../analytics_channel.dart';

/// PostHog 分析上报通道
class PostHogChannel implements AnalyticsChannel {
  static const _apiKey = String.fromEnvironment(
    'POSTHOG_API_KEY',
    defaultValue: 'phc_s2ZWTJV3n57Tcz16OYZailIJroIUJhWEXmHMothJ5MZ',
  );
  static const _host = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://us.i.posthog.com',
  );

  /// 始终已配置（内置默认 API Key）
  static bool get isConfigured => true;

  @override
  String get name => 'PostHog';

  @override
  Future<void> initialize() async {
    final config = PostHogConfig(_apiKey)
      ..host = _host
      ..flushAt = 5
      ..flushInterval = const Duration(seconds: 3)
      ..personProfiles = PostHogPersonProfiles.always
      ..sessionReplay = true
      ..sessionReplayConfig.maskAllTexts = false
      ..sessionReplayConfig.maskAllImages = false
      ..debug = true;
    await Posthog().setup(config);
  }

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {
    await Posthog().capture(eventName: name, properties: parameters);
  }

  @override
  Future<void> setUserId(String? id) {
    if (id == null) return Posthog().reset();
    return Posthog().identify(userId: id);
  }

  @override
  Future<void> setUserProperty(String name, String? value) {
    return Posthog().setPersonProperties(
      userPropertiesToSet: {name: value ?? ''},
    );
  }

  @override
  Future<void> registerSuperProperties(Map<String, Object> properties) async {
    // PostHog SDK 5.x 的 register 一次只接受一个 key/value，循环写入即可。
    for (final entry in properties.entries) {
      await Posthog().register(entry.key, entry.value);
    }
  }
}