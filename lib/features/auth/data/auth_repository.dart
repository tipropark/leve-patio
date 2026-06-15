import 'package:dio/dio.dart';
import 'package:leve_core/leve_core.dart';

import '../../../core/config/env.dart';
import '../../operacao/domain/operacao_resumo.dart';
import '../domain/patio_user.dart';
import 'token_storage.dart';

class LoginResult {
  const LoginResult({
    required this.user,
    required this.operacoes,
  });
  final PatioUser user;
  final List<OperacaoResumo> operacoes;
}

class BindingInfo {
  const BindingInfo({
    required this.operacaoId,
    required this.nomeOperacao,
    required this.codigoOperacao,
  });
  final String operacaoId;
  final String nomeOperacao;
  final String codigoOperacao;
}

class AuthRepository {
  AuthRepository({required this.dio, required this.storage});

  final Dio dio;
  final TokenStorage storage;

  /// Login completo: autentica, persiste tokens e retorna usuário + operações.
  Future<LoginResult> login({
    required String matricula,
    required String password,
  }) async {
    try {
      final deviceUuid = await storage.getOrCreateDeviceUuid();
      final resp = await dio.post(
        '${Env.authBase}/login',
        data: {
          'matricula':   matricula.trim().toUpperCase(),
          'password':    password,
          'device_uuid': deviceUuid,
          'plataforma':  'android',
        },
        // Sem Authorization nesta chamada
        options: Options(headers: {'Authorization': null}),
      );

      final data = resp.data as Map<String, dynamic>;
      final user = PatioUser.fromJson(data['user'] as Map<String, dynamic>);
      final operacoes = (data['operacoes'] as List)
          .map((o) => OperacaoResumo.fromJson(o as Map<String, dynamic>))
          .toList();

      await storage.saveTokens(
        accessToken:  data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
      await storage.saveUser(user);

      return LoginResult(user: user, operacoes: operacoes);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Verifica se o dispositivo está vinculado a um pátio.
  /// Retorna [BindingInfo] se vinculado, ou null se não registrado/revogado.
  /// Lança exceção em caso de erro de rede (deixa o chamador decidir o fallback).
  Future<BindingInfo?> checkDeviceBinding(String deviceUuid) async {
    try {
      final resp = await dio.get(
        Env.dispositivoUrl,
        options: Options(
          headers: {'X-Device-Id': deviceUuid},
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      if (resp.statusCode == 200) {
        final data = resp.data as Map<String, dynamic>;
        return BindingInfo(
          operacaoId:    data['operacao_id']     as String,
          nomeOperacao:  data['nome_operacao']   as String? ?? '',
          codigoOperacao: data['codigo_operacao'] as String? ?? '',
        );
      }
      // 404 = não registrado, 403 = revogado → ambos retornam null
      return null;
    } on DioException {
      rethrow; // Deixa o AuthController tratar como falha de rede
    }
  }

  /// Logout: revoga tokens no servidor e limpa storage local.
  Future<void> logout() async {
    try {
      final refresh  = await storage.readRefreshToken();
      final deviceId = await storage.readDeviceUuid();
      if (refresh != null && deviceId != null) {
        await dio.post(
          '${Env.authBase}/logout',
          data: {'refresh_token': refresh, 'device_uuid': deviceId},
          options: Options(validateStatus: (s) => s != null && s < 500),
        );
      }
    } catch (_) {
      // Falha remota não impede logout local.
    } finally {
      await storage.clearAll();
    }
  }
}
