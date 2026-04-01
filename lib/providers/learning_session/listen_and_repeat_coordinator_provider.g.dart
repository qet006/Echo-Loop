// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'listen_and_repeat_coordinator_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$listenAndRepeatCoordinatorHash() =>
    r'6882994b47a4f8d6175b641e1bfc718080015294';

/// 跟读协调 Provider
///
/// keepAlive 确保在页面生命周期内始终活跃。
/// 通过 ref.listen 监听 player 和 recording 状态变化，自动触发协调逻辑。
///
/// Copied from [ListenAndRepeatCoordinator].
@ProviderFor(ListenAndRepeatCoordinator)
final listenAndRepeatCoordinatorProvider =
    NotifierProvider<ListenAndRepeatCoordinator, void>.internal(
      ListenAndRepeatCoordinator.new,
      name: r'listenAndRepeatCoordinatorProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$listenAndRepeatCoordinatorHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ListenAndRepeatCoordinator = Notifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
