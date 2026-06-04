import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/auth_config.dart' as auth_config;

/// Google 登录交给 Supabase 校验所需的 token。
///
/// `idToken` 表示用户身份，`accessToken` 让 Supabase 能按 Google provider
/// 完成标准 native token 登录流程。
class GoogleSignInCredentials {
  const GoogleSignInCredentials({
    required this.idToken,
    required this.accessToken,
  });

  final String idToken;
  final String accessToken;
}

/// Google 登录凭证获取接口。
///
/// 生产环境通过 Google Sign-In 原生 SDK 获取 token；测试环境注入替身，避免
/// 单测依赖 Google Play services 或系统账号面板。
abstract class GoogleSignInCredentialsProvider {
  Future<GoogleSignInCredentials> getCredentials();
}

class NativeGoogleSignInCredentialsProvider
    implements GoogleSignInCredentialsProvider {
  NativeGoogleSignInCredentialsProvider({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  static const _scopes = ['email', 'profile', 'openid'];

  final GoogleSignIn _googleSignIn;
  Future<void>? _initializeFuture;

  /// 初始化 Google Sign-In SDK。
  ///
  /// Google 7.x API 要求先完成 `initialize` 才能发起交互式登录。这里缓存
  /// Future，避免同一个 provider 实例内重复初始化。
  Future<void> _initialize() {
    final existing = _initializeFuture;
    if (existing != null) return existing;

    final clientId = auth_config.googleWebClientId;
    if (clientId.isEmpty) {
      throw const AuthException('Google OAuth client is not configured.');
    }

    final future = _googleSignIn.initialize(serverClientId: clientId);
    _initializeFuture = future;
    return future;
  }

  @override
  Future<GoogleSignInCredentials> getCredentials() async {
    await _initialize();

    final account = await _googleSignIn.authenticate(scopeHint: _scopes);
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Google identity token is missing.');
    }

    final authorization =
        await account.authorizationClient.authorizationForScopes(_scopes) ??
        await account.authorizationClient.authorizeScopes(_scopes);
    final accessToken = authorization.accessToken;
    if (accessToken.isEmpty) {
      throw const AuthException('Google access token is missing.');
    }

    return GoogleSignInCredentials(idToken: idToken, accessToken: accessToken);
  }
}
