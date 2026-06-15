import 'package:dio/dio.dart';

import '../../features/auth/data/token_storage.dart';

/// Injeta `Authorization: Bearer token` e `X-Device-Id` em toda requisição autenticada.
class BearerInterceptor extends Interceptor {
  BearerInterceptor(this._storage);

  final TokenStorage _storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token      = await _storage.readAccessToken();
    final deviceUuid = await _storage.readDeviceUuid();

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    if (deviceUuid != null && deviceUuid.isNotEmpty) {
      options.headers['X-Device-Id'] = deviceUuid;
    }
    handler.next(options);
  }
}
