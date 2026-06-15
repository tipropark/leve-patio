import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import 'auth_provider.dart';

/// Verifica o estado inicial do app sem chamadas de rede bloqueantes.
///
/// Fluxo: access token + user salvos → AuthLoggedIn (sessão restaurada)
///        caso contrário             → AuthLoggedOut
class StartupNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    final storage = ref.read(tokenStorageProvider);
    final auth    = ref.read(authControllerProvider.notifier);

    final accessToken = await storage.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      auth.onLoggedOut();
      return;
    }

    final user = await storage.readUser();
    if (user == null) {
      await storage.clearAll();
      auth.onLoggedOut();
      return;
    }

    auth.continuarOffline(user);
  }
}

final startupProvider =
    AsyncNotifierProvider<StartupNotifier, void>(StartupNotifier.new);
