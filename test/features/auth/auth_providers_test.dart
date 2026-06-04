/// `supabaseSessionProvider` / `isAuthenticatedProvider` 基线测试。
///
/// 步骤 0 阶段：Supabase 凭据未通过 `--dart-define` 注入，
/// `isAuthConfigured == false`，provider 走 fallback 分支永远 emit `null`。
/// 验证 fallback 分支不崩、行为合理，避免后续步骤回归。
library;

import 'package:echo_loop/analytics/analytics_providers.dart';
import 'package:echo_loop/analytics/analytics_service.dart';
import 'package:echo_loop/features/auth/apple_sign_in_credentials.dart';
import 'package:echo_loop/features/auth/google_sign_in_credentials.dart';
import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/services/user_id_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _FakeAppleCredentialsProvider implements AppleSignInCredentialsProvider {
  _FakeAppleCredentialsProvider(this.credential);

  final AuthorizationCredentialAppleID credential;
  String? receivedNonce;

  @override
  Future<AuthorizationCredentialAppleID> getCredential({
    required String nonce,
  }) async {
    receivedNonce = nonce;
    return credential;
  }
}

class _FakeGoogleCredentialsProvider
    implements GoogleSignInCredentialsProvider {
  _FakeGoogleCredentialsProvider(this.credentials);

  final GoogleSignInCredentials credentials;

  @override
  Future<GoogleSignInCredentials> getCredentials() async {
    return credentials;
  }
}

class _ThrowingGoogleCredentialsProvider
    implements GoogleSignInCredentialsProvider {
  @override
  Future<GoogleSignInCredentials> getCredentials() async {
    throw const AuthException('Google identity token is missing.');
  }
}

class _FakeUserAttributes extends Fake implements UserAttributes {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUserAttributes());
    registerFallbackValue(OAuthProvider.apple);
  });

  group('supabaseSessionProvider（Supabase 未配置 fallback 分支）', () {
    test('首值 emit null（匿名态）', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(supabaseSessionProvider.future);

      final value = container.read(supabaseSessionProvider).valueOrNull;
      expect(value, isNull);
    });

    test('Stream 完成且不抛错', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final future = container.read(supabaseSessionProvider.future);
      expect(await future, isNull);
    });
  });

  group('isAuthenticatedProvider', () {
    test('未配置时为 false', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(supabaseSessionProvider.future);

      expect(container.read(isAuthenticatedProvider), isFalse);
    });
  });

  group('AuthController', () {
    late _MockAuthRepository repository;
    late _MockAnalyticsService analytics;
    late ProviderContainer container;

    setUp(() {
      repository = _MockAuthRepository();
      analytics = _MockAnalyticsService();
      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          analyticsServiceProvider.overrideWithValue(analytics),
          userIdProvider.overrideWithValue('anon-123'),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('requestEmailOtp 通过统一仓库发送验证码', () async {
      when(
        () => repository.sendEmailOtp('user@example.com'),
      ).thenAnswer((_) async {});

      await container
          .read(authControllerProvider)
          .requestEmailOtp('user@example.com');

      verify(() => repository.sendEmailOtp('user@example.com')).called(1);
    });

    test('verifyEmailOtp 通过统一仓库验证并同步 analytics 身份属性', () async {
      final user = User(
        id: 'user-1',
        email: 'user@example.com',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-06-03T00:00:00.000Z',
      );
      final response = AuthResponse(session: null, user: user);

      when(
        () => repository.verifyEmailOtp(
          email: 'user@example.com',
          token: '123456',
        ),
      ).thenAnswer((_) async => response);
      when(() => analytics.setUserId('user-1')).thenAnswer((_) async {});
      when(
        () => analytics.registerSuperProperties({'supabase_user_id': 'user-1'}),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('email', 'user@example.com'),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).thenAnswer((_) async {});

      await container
          .read(authControllerProvider)
          .verifyEmailOtp(email: 'user@example.com', token: '123456');

      verify(
        () => repository.verifyEmailOtp(
          email: 'user@example.com',
          token: '123456',
        ),
      ).called(1);
      verify(() => analytics.setUserId('user-1')).called(1);
      verify(
        () => analytics.registerSuperProperties({'supabase_user_id': 'user-1'}),
      ).called(1);
      verify(
        () => analytics.setUserProperty('email', 'user@example.com'),
      ).called(1);
      verify(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).called(1);
    });

    test('verifyEmailOtp 无邮箱时跳过 email 属性，但仍绑定匿名 ID', () async {
      final user = User(
        id: 'user-1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-06-03T00:00:00.000Z',
      );
      final response = AuthResponse(session: null, user: user);

      when(
        () => repository.verifyEmailOtp(
          email: 'user@example.com',
          token: '123456',
        ),
      ).thenAnswer((_) async => response);
      when(() => analytics.setUserId('user-1')).thenAnswer((_) async {});
      when(
        () => analytics.registerSuperProperties({'supabase_user_id': 'user-1'}),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).thenAnswer((_) async {});

      await container
          .read(authControllerProvider)
          .verifyEmailOtp(email: 'user@example.com', token: '123456');

      verify(() => analytics.setUserId('user-1')).called(1);
      verify(
        () => analytics.registerSuperProperties({'supabase_user_id': 'user-1'}),
      ).called(1);
      verify(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).called(1);
      verifyNever(() => analytics.setUserProperty('email', any()));
    });

    test('signInWithApple 通过统一仓库登录并同步 analytics 身份属性', () async {
      final user = User(
        id: 'apple-user-1',
        email: 'apple@example.com',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-06-04T00:00:00.000Z',
      );
      final response = AuthResponse(session: null, user: user);

      when(
        () => repository.signInWithApple(),
      ).thenAnswer((_) async => response);
      when(() => analytics.setUserId('apple-user-1')).thenAnswer((_) async {});
      when(
        () => analytics.registerSuperProperties({
          'supabase_user_id': 'apple-user-1',
        }),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('email', 'apple@example.com'),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).thenAnswer((_) async {});

      await container.read(authControllerProvider).signInWithApple();

      verify(() => repository.signInWithApple()).called(1);
      verify(() => analytics.setUserId('apple-user-1')).called(1);
      verify(
        () => analytics.registerSuperProperties({
          'supabase_user_id': 'apple-user-1',
        }),
      ).called(1);
      verify(
        () => analytics.setUserProperty('email', 'apple@example.com'),
      ).called(1);
      verify(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).called(1);
    });

    test('signInWithApple 无邮箱时跳过 email 属性，但仍绑定匿名 ID', () async {
      final user = User(
        id: 'apple-user-1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-06-04T00:00:00.000Z',
      );
      final response = AuthResponse(session: null, user: user);

      when(
        () => repository.signInWithApple(),
      ).thenAnswer((_) async => response);
      when(() => analytics.setUserId('apple-user-1')).thenAnswer((_) async {});
      when(
        () => analytics.registerSuperProperties({
          'supabase_user_id': 'apple-user-1',
        }),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).thenAnswer((_) async {});

      await container.read(authControllerProvider).signInWithApple();

      verify(() => repository.signInWithApple()).called(1);
      verify(() => analytics.setUserId('apple-user-1')).called(1);
      verify(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).called(1);
      verifyNever(() => analytics.setUserProperty('email', any()));
    });

    test('signInWithGoogle 通过统一仓库登录并同步 analytics 身份属性', () async {
      final user = User(
        id: 'google-user-1',
        email: 'google@example.com',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-06-04T00:00:00.000Z',
      );
      final response = AuthResponse(session: null, user: user);

      when(
        () => repository.signInWithGoogle(),
      ).thenAnswer((_) async => response);
      when(() => analytics.setUserId('google-user-1')).thenAnswer((_) async {});
      when(
        () => analytics.registerSuperProperties({
          'supabase_user_id': 'google-user-1',
        }),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('email', 'google@example.com'),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).thenAnswer((_) async {});

      await container.read(authControllerProvider).signInWithGoogle();

      verify(() => repository.signInWithGoogle()).called(1);
      verify(() => analytics.setUserId('google-user-1')).called(1);
      verify(
        () => analytics.registerSuperProperties({
          'supabase_user_id': 'google-user-1',
        }),
      ).called(1);
      verify(
        () => analytics.setUserProperty('email', 'google@example.com'),
      ).called(1);
      verify(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).called(1);
    });

    test('signOut 通过统一仓库退出并清理 analytics userId', () async {
      when(() => repository.signOut()).thenAnswer((_) async {});
      when(() => analytics.setUserId(null)).thenAnswer((_) async {});

      await container.read(authControllerProvider).signOut();

      verify(() => repository.signOut()).called(1);
      verify(() => analytics.setUserId(null)).called(1);
    });
  });

  group('SupabaseAuthRepository Google 登录', () {
    late _MockGoTrueClient auth;
    late User user;

    setUp(() {
      auth = _MockGoTrueClient();
      user = User(
        id: 'google-user-1',
        email: 'google@example.com',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-06-04T00:00:00.000Z',
      );
    });

    test('用 Google id token 和 access token 交换 Supabase session', () async {
      final repository = SupabaseAuthRepository(
        auth,
        googleCredentialsProvider: _FakeGoogleCredentialsProvider(
          const GoogleSignInCredentials(
            idToken: 'google-id-token',
            accessToken: 'google-access-token',
          ),
        ),
      );

      when(
        () => auth.signInWithIdToken(
          provider: any(named: 'provider'),
          idToken: any(named: 'idToken'),
          accessToken: any(named: 'accessToken'),
        ),
      ).thenAnswer((_) async => AuthResponse(session: null, user: user));

      final response = await repository.signInWithGoogle();

      expect(response.user?.id, 'google-user-1');
      verify(
        () => auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: 'google-id-token',
          accessToken: 'google-access-token',
        ),
      ).called(1);
    });

    test('凭证获取失败时不调用 Supabase', () async {
      final repository = SupabaseAuthRepository(
        auth,
        googleCredentialsProvider: _ThrowingGoogleCredentialsProvider(),
      );

      expect(repository.signInWithGoogle(), throwsA(isA<AuthException>()));
      verifyNever(
        () => auth.signInWithIdToken(
          provider: any(named: 'provider'),
          idToken: any(named: 'idToken'),
          accessToken: any(named: 'accessToken'),
        ),
      );
    });
  });

  group('SupabaseAuthRepository Apple 登录', () {
    late _MockGoTrueClient auth;
    late User user;

    setUp(() {
      auth = _MockGoTrueClient();
      user = User(
        id: 'apple-user-1',
        email: 'apple@example.com',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-06-04T00:00:00.000Z',
      );
    });

    AuthorizationCredentialAppleID appleCredential({
      String? identityToken = 'apple-id-token',
      String? givenName = ' Ada ',
      String? familyName = ' Lovelace ',
    }) {
      return AuthorizationCredentialAppleID(
        userIdentifier: 'apple-user-id',
        givenName: givenName,
        familyName: familyName,
        authorizationCode: 'authorization-code',
        email: 'apple@example.com',
        identityToken: identityToken,
        state: null,
      );
    }

    test('将 hashed nonce 传给 Apple，并用 raw nonce 交换 Supabase session', () async {
      final appleProvider = _FakeAppleCredentialsProvider(appleCredential());
      final repository = SupabaseAuthRepository(
        auth,
        appleCredentialsProvider: appleProvider,
      );

      when(
        () => auth.signInWithIdToken(
          provider: any(named: 'provider'),
          idToken: any(named: 'idToken'),
          nonce: any(named: 'nonce'),
        ),
      ).thenAnswer((_) async => AuthResponse(session: null, user: user));
      when(
        () => auth.updateUser(any()),
      ).thenAnswer((_) async => UserResponse.fromJson(user.toJson()));

      final response = await repository.signInWithApple();

      expect(response.user?.id, 'apple-user-1');
      final rawNonce =
          verify(
                () => auth.signInWithIdToken(
                  provider: OAuthProvider.apple,
                  idToken: 'apple-id-token',
                  nonce: captureAny(named: 'nonce'),
                ),
              ).captured.single
              as String;
      expect(rawNonce, hasLength(32));
      expect(appleProvider.receivedNonce, isNot(rawNonce));
      expect(appleProvider.receivedNonce, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('首次返回姓名时写入 user metadata', () async {
      final appleProvider = _FakeAppleCredentialsProvider(appleCredential());
      final repository = SupabaseAuthRepository(
        auth,
        appleCredentialsProvider: appleProvider,
      );

      when(
        () => auth.signInWithIdToken(
          provider: any(named: 'provider'),
          idToken: any(named: 'idToken'),
          nonce: any(named: 'nonce'),
        ),
      ).thenAnswer((_) async => AuthResponse(session: null, user: user));
      when(
        () => auth.updateUser(any()),
      ).thenAnswer((_) async => UserResponse.fromJson(user.toJson()));

      await repository.signInWithApple();

      final attributes =
          verify(() => auth.updateUser(captureAny())).captured.single
              as UserAttributes;
      expect(attributes.data, {
        'full_name': 'Ada Lovelace',
        'given_name': 'Ada',
        'family_name': 'Lovelace',
      });
    });

    test('缺少 identity token 时抛认证异常且不调用 Supabase', () async {
      final appleProvider = _FakeAppleCredentialsProvider(
        appleCredential(identityToken: null),
      );
      final repository = SupabaseAuthRepository(
        auth,
        appleCredentialsProvider: appleProvider,
      );

      expect(repository.signInWithApple(), throwsA(isA<AuthException>()));
      verifyNever(
        () => auth.signInWithIdToken(
          provider: any(named: 'provider'),
          idToken: any(named: 'idToken'),
          nonce: any(named: 'nonce'),
        ),
      );
      verifyNever(() => auth.updateUser(any()));
    });

    test('metadata 更新失败不撤销已建立 session', () async {
      final appleProvider = _FakeAppleCredentialsProvider(appleCredential());
      final repository = SupabaseAuthRepository(
        auth,
        appleCredentialsProvider: appleProvider,
      );

      when(
        () => auth.signInWithIdToken(
          provider: any(named: 'provider'),
          idToken: any(named: 'idToken'),
          nonce: any(named: 'nonce'),
        ),
      ).thenAnswer((_) async => AuthResponse(session: null, user: user));
      when(
        () => auth.updateUser(any()),
      ).thenThrow(const AuthException('metadata update failed'));

      final response = await repository.signInWithApple();

      expect(response.user?.id, 'apple-user-1');
      verify(() => auth.updateUser(any())).called(1);
    });
  });

  group('AuthAnalyticsSync', () {
    late _MockAnalyticsService analytics;
    late ProviderContainer container;

    setUp(() {
      analytics = _MockAnalyticsService();
      when(() => analytics.setUserId(any())).thenAnswer((_) async {});
      when(
        () => analytics.registerSuperProperties(any()),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => analytics.unregisterSuperProperty(any()),
      ).thenAnswer((_) async {});
      container = ProviderContainer(
        overrides: [
          analyticsServiceProvider.overrideWithValue(analytics),
          userIdProvider.overrideWithValue('anon-123'),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('syncSignedInUser 同步真实 ID、邮箱和匿名 ID', () async {
      final user = User(
        id: 'user-1',
        email: 'user@example.com',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-06-03T00:00:00.000Z',
      );

      when(() => analytics.setUserId('user-1')).thenAnswer((_) async {});
      when(
        () => analytics.registerSuperProperties({'supabase_user_id': 'user-1'}),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('email', 'user@example.com'),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).thenAnswer((_) async {});

      await container.read(authAnalyticsSyncProvider).syncSignedInUser(user);

      verify(() => analytics.setUserId('user-1')).called(1);
      verify(
        () => analytics.registerSuperProperties({'supabase_user_id': 'user-1'}),
      ).called(1);
      verify(
        () => analytics.setUserProperty('email', 'user@example.com'),
      ).called(1);
      verify(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).called(1);
    });

    test('syncSessionChange 首次恢复已登录 session 也会同步身份', () async {
      final user = User(
        id: 'user-1',
        email: 'user@example.com',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-06-03T00:00:00.000Z',
      );
      final session = Session(
        accessToken: 'access',
        refreshToken: 'refresh',
        tokenType: 'bearer',
        user: user,
      );

      when(() => analytics.setUserId('user-1')).thenAnswer((_) async {});
      when(
        () => analytics.registerSuperProperties({'supabase_user_id': 'user-1'}),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('email', 'user@example.com'),
      ).thenAnswer((_) async {});
      when(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).thenAnswer((_) async {});

      await container
          .read(authAnalyticsSyncProvider)
          .syncSessionChange(previous: null, current: session);

      verify(() => analytics.setUserId('user-1')).called(1);
      verify(
        () => analytics.setUserProperty('email', 'user@example.com'),
      ).called(1);
      verify(
        () => analytics.setUserProperty('app_anonymous_id', 'anon-123'),
      ).called(1);
    });

    test('syncSessionChange 仅在已登录 -> 已登出时 reset analytics', () async {
      final user = User(
        id: 'user-1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-06-03T00:00:00.000Z',
      );
      final session = Session(
        accessToken: 'access',
        refreshToken: 'refresh',
        tokenType: 'bearer',
        user: user,
      );

      when(() => analytics.setUserId(null)).thenAnswer((_) async {});
      when(
        () => analytics.unregisterSuperProperty('supabase_user_id'),
      ).thenAnswer((_) async {});

      await container
          .read(authAnalyticsSyncProvider)
          .syncSessionChange(previous: session, current: null);

      verify(
        () => analytics.unregisterSuperProperty('supabase_user_id'),
      ).called(1);
      verify(() => analytics.setUserId(null)).called(1);
    });

    test('syncSessionChange 匿名启动时不 reset analytics', () async {
      await container
          .read(authAnalyticsSyncProvider)
          .syncSessionChange(previous: null, current: null);

      verifyNever(() => analytics.setUserId(null));
    });
  });
}
