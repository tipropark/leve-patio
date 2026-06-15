import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/utils/version_utils.dart';
import '../../domain/patio_user.dart';
import 'auth_provider.dart';

/// Watches for AuthLoggedIn transitions and checks the remote app-config for
/// minimum version requirements. Does NOT block app startup — fires async and
/// silently ignores network failures (offline-first).
class VersionGateNotifier extends Notifier<void> {
  PatioUser? _lastUser;

  @override
  void build() {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthLoggedIn && previous is! AuthLoggedIn) {
        _lastUser = next.user;
        Future.microtask(_check);
      }
    });
  }

  Future<void> _check() async {
    final user = _lastUser;
    if (user == null) return;
    try {
      final config =
          await ref.read(appConfigRepositoryProvider).fetch();
      if (VersionUtils.isUpdateRequired(Env.appVersion, config.minVersion)) {
        ref.read(authControllerProvider.notifier).onNeedsUpdate(
          user,
          config.minVersion,
          forceUpdate: config.forceUpdate,
        );
      }
    } catch (_) {
      // Network failure → do not block the app.
    }
  }
}

final versionGateProvider =
    NotifierProvider<VersionGateNotifier, void>(VersionGateNotifier.new);
