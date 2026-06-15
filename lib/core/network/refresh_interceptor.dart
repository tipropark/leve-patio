import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/token_storage.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// Intercepta 401, tenta renovar o access token via refresh token e repete
/// os requests originais. Se o refresh for negado (token revogado), limpa
/// a sessão e seta o estado de auth como revogado.
class RefreshInterceptor extends Interceptor {
  RefreshInterceptor({
    required this.dio,
    required this.storage,
    required this.ref,
  });

  final Dio dio;
  final TokenStorage storage;
  final Ref ref;

  bool _refreshing = false;
  final List<({RequestOptions options, ErrorInterceptorHandler handler})> _queue = [];

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    // Evita loops: se o 401 veio da rota de refresh, é token revogado.
    if (err.requestOptions.path.contains('/auth/refresh')) {
      await storage.clearAll();
      ref.read(authControllerProvider.notifier).onRevogado();
      handler.next(err);
      return;
    }

    // Enquanto já há um refresh em andamento, enfileira.
    if (_refreshing) {
      _queue.add((options: err.requestOptions, handler: handler));
      return;
    }

    _refreshing = true;
    try {
      final refreshToken = await storage.readRefreshToken();
      final deviceUuid = await storage.readDeviceUuid();
      if (refreshToken == null || deviceUuid == null) {
        throw DioException(requestOptions: err.requestOptions);
      }

      final resp = await dio.post(
        '/api/mobile/v1/patio/auth/refresh',
        data: {'refresh_token': refreshToken, 'device_uuid': deviceUuid},
        options: Options(headers: {'Authorization': null}), // sem Bearer no refresh
      );

      final newAccess  = resp.data['access_token'] as String;
      final newRefresh = resp.data['refresh_token'] as String;
      await storage.saveTokens(accessToken: newAccess, refreshToken: newRefresh);

      // Repete o request original com o novo token.
      err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
      final retry = await dio.fetch(err.requestOptions);
      handler.resolve(retry);

      // Repete os requests enfileirados.
      for (final item in _queue) {
        item.options.headers['Authorization'] = 'Bearer $newAccess';
        try {
          final r = await dio.fetch(item.options);
          item.handler.resolve(r);
        } catch (e) {
          item.handler.next(err);
        }
      }
    } catch (_) {
      // Refresh falhou — dispositivo revogado ou sem rede.
      await storage.clearAll();
      ref.read(authControllerProvider.notifier).onRevogado();
      for (final item in _queue) {
        item.handler.next(err);
      }
      handler.next(err);
    } finally {
      _queue.clear();
      _refreshing = false;
    }
  }
}
