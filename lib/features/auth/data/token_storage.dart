import 'dart:convert';

import 'package:leve_core/leve_core.dart';
import 'package:uuid/uuid.dart';

import '../domain/patio_user.dart';

/// Chaves no flutter_secure_storage.
abstract final class _K {
  static const accessToken  = 'patio_access_token';
  static const refreshToken = 'patio_refresh_token';
  static const userJson     = 'patio_user_json';
  static const deviceUuid   = 'patio_device_uuid';
  static const operacaoId   = 'patio_operacao_id';
  static const patioNome    = 'patio_nome_vinculado';
  static const patioCodigo  = 'patio_codigo_vinculado';
}

/// Persiste tokens e identidade do dispositivo em SecureStorage.
///
/// NUNCA armazena a senha do usuário.
class TokenStorage {
  TokenStorage(this._storage);

  final SecureStorage _storage;

  // ── Access / Refresh tokens ───────────────────────────────────────────────

  Future<String?> readAccessToken()  => _storage.read(_K.accessToken);
  Future<String?> readRefreshToken() => _storage.read(_K.refreshToken);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(_K.accessToken, accessToken);
    await _storage.write(_K.refreshToken, refreshToken);
  }

  // ── Usuário ───────────────────────────────────────────────────────────────

  Future<PatioUser?> readUser() async {
    final json = await _storage.read(_K.userJson);
    if (json == null) return null;
    return PatioUser.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> saveUser(PatioUser user) =>
      _storage.write(_K.userJson, jsonEncode(user.toJson()));

  // ── Device UUID ───────────────────────────────────────────────────────────

  /// Retorna o UUID do dispositivo, criando-o na primeira chamada.
  Future<String> getOrCreateDeviceUuid() async {
    var id = await _storage.read(_K.deviceUuid);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await _storage.write(_K.deviceUuid, id);
    }
    return id;
  }

  Future<String?> readDeviceUuid() => _storage.read(_K.deviceUuid);

  // ── Operação selecionada ──────────────────────────────────────────────────

  Future<String?> readOperacaoId()           => _storage.read(_K.operacaoId);
  Future<void>    saveOperacaoId(String id)  => _storage.write(_K.operacaoId, id);

  // ── Pátio vinculado (cache para login screen) ─────────────────────────────

  Future<String?> readPatioNome()    => _storage.read(_K.patioNome);
  Future<String?> readPatioCodigo()  => _storage.read(_K.patioCodigo);

  Future<void> savePatioVinculado({ required String nome, required String codigo }) async {
    await _storage.write(_K.patioNome,   nome);
    await _storage.write(_K.patioCodigo, codigo);
  }

  // ── Limpeza ───────────────────────────────────────────────────────────────

  Future<void> clearSession() async {
    await _storage.delete(_K.accessToken);
    await _storage.delete(_K.refreshToken);
    await _storage.delete(_K.userJson);
  }

  /// Remove tudo — chamado em logout completo ou revogação de dispositivo.
  Future<void> clearAll() async {
    await _storage.delete(_K.accessToken);
    await _storage.delete(_K.refreshToken);
    await _storage.delete(_K.userJson);
    await _storage.delete(_K.operacaoId);
    await _storage.delete(_K.patioNome);
    await _storage.delete(_K.patioCodigo);
    // device_uuid é preservado intencionalmente (identidade do hardware)
  }
}
