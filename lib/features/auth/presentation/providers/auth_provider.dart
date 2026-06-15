import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../data/auth_repository.dart';
import '../../data/token_storage.dart';
import '../../domain/patio_user.dart';
import '../../../operacao/domain/operacao_resumo.dart';

// ── Estado ────────────────────────────────────────────────────────────────

sealed class AuthState {
  const AuthState();
}

class AuthLoading             extends AuthState { const AuthLoading(); }
class AuthLoggedOut           extends AuthState { const AuthLoggedOut(); }
class AuthRevogado            extends AuthState { const AuthRevogado(); }

class AuthNeedOperacao extends AuthState {
  const AuthNeedOperacao({
    required this.user,
    required this.operacoes,
    this.isFirstLogin = false,
  });
  final PatioUser user;
  final List<OperacaoResumo> operacoes;
  final bool isFirstLogin;
}

/// Dispositivo instalado mas ainda não vinculado a nenhum pátio no ERP.
class AuthDeviceNaoVinculado extends AuthState {
  const AuthDeviceNaoVinculado({
    required this.user,
    required this.deviceUuid,
    required this.operacoes,
  });
  final PatioUser user;
  final String deviceUuid;
  final List<OperacaoResumo> operacoes;
}

class AuthLoggedIn extends AuthState {
  const AuthLoggedIn(this.user);
  final PatioUser user;
}

class AuthNeedsUpdate extends AuthState {
  const AuthNeedsUpdate({
    required this.user,
    required this.minVersion,
    this.forceUpdate = true,
  });
  final PatioUser user;
  final String minVersion;
  final bool forceUpdate;
}

// ── Controller ────────────────────────────────────────────────────────────

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthLoading();

  TokenStorage   get _storage => ref.read(tokenStorageProvider);
  AuthRepository get _repo    => ref.read(authRepositoryProvider);

  // Chamados pelo StartupNotifier / VersionGateNotifier
  void onLoggedOut()              => state = const AuthLoggedOut();
  void continuarOffline(PatioUser user) => state = AuthLoggedIn(user);
  void onRevogado()               => state = const AuthRevogado();

  void onNeedsUpdate(
    PatioUser user,
    String minVersion, {
    bool forceUpdate = true,
  }) =>
      state = AuthNeedsUpdate(
        user:        user,
        minVersion:  minVersion,
        forceUpdate: forceUpdate,
      );

  // ── Login online ──────────────────────────────────────────────────────

  Future<void> login({required String matricula, required String password}) async {
    try {
      final result = await _repo.login(matricula: matricula, password: password);
      await _storage.saveUser(result.user);
      await _resolverAposLogin(result.user, result.operacoes, isFirstLogin: true);
    } catch (e) {
      state = const AuthLoggedOut();
      rethrow;
    }
  }

  // ── Resolução de operação pós-login ───────────────────────────────────

  Future<void> _resolverAposLogin(
    PatioUser user,
    List<OperacaoResumo> operacoes, {
    required bool isFirstLogin,
  }) async {
    try {
      final deviceUuid = await _storage.getOrCreateDeviceUuid();
      final vinculo    = await _repo.checkDeviceBinding(deviceUuid);

      if (vinculo != null) {
        await _storage.saveOperacaoId(vinculo.operacaoId);
        await _storage.savePatioVinculado(
          nome:   vinculo.nomeOperacao,
          codigo: vinculo.codigoOperacao,
        );
        state = AuthLoggedIn(user);
        return;
      }
    } catch (_) {
      // Falha de rede → não bloquear; cair no fluxo normal
    }

    final deviceUuid = await _storage.readDeviceUuid() ?? '';
    if (operacoes.length == 1) {
      await _storage.saveOperacaoId(operacoes.first.id);
      state = AuthLoggedIn(user);
    } else {
      state = AuthDeviceNaoVinculado(
        user:       user,
        deviceUuid: deviceUuid,
        operacoes:  operacoes,
      );
    }
  }

  // ── Verificar vínculo manualmente (botão "Verificar novamente") ───────

  Future<void> verificarVinculo() async {
    final current = state;
    if (current is! AuthDeviceNaoVinculado) return;

    state = const AuthLoading();
    try {
      final deviceUuid = await _storage.getOrCreateDeviceUuid();
      final vinculo    = await _repo.checkDeviceBinding(deviceUuid);

      if (vinculo != null) {
        await _storage.saveOperacaoId(vinculo.operacaoId);
        await _storage.savePatioVinculado(
          nome:   vinculo.nomeOperacao,
          codigo: vinculo.codigoOperacao,
        );
        state = AuthLoggedIn(current.user);
      } else {
        state = AuthDeviceNaoVinculado(
          user:       current.user,
          deviceUuid: deviceUuid,
          operacoes:  current.operacoes,
        );
      }
    } catch (_) {
      state = AuthDeviceNaoVinculado(
        user:       current.user,
        deviceUuid: current.deviceUuid,
        operacoes:  current.operacoes,
      );
    }
  }

  // ── Seleção manual de operação (fallback) ─────────────────────────────

  void selecionarOperacaoManual(PatioUser user, List<OperacaoResumo> operacoes) {
    state = AuthNeedOperacao(
      user:         user,
      operacoes:    operacoes,
      isFirstLogin: true,
    );
  }

  Future<void> selecionarOperacao(
    PatioUser user,
    String operacaoId, {
    required bool isFirstLogin,
  }) async {
    await _storage.saveOperacaoId(operacaoId);
    state = AuthLoggedIn(user);
  }

  // ── Logout ────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthLoggedOut();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
