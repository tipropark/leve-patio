import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import 'providers/sync_provider.dart';

class SyncLifecycleNotifier extends Notifier<void> {
  Timer? _timer;

  @override
  void build() {
    ref.onDispose(() => _timer?.cancel());

    // Trigger on every AuthLoggedIn transition
    ref.listen(authControllerProvider, (_, next) {
      if (next is AuthLoggedIn) {
        Future.microtask(
          () => ref.read(syncNotifierProvider.notifier).trigger(),
        );
      }
    });

    // Periodic sync every [Env.syncInterval] only if authenticated
    _timer = Timer.periodic(Env.syncInterval, (_) {
      final auth = ref.read(authControllerProvider);
      if (auth is AuthLoggedIn) {
        ref.read(syncNotifierProvider.notifier).trigger();
      }
    });
  }
}

final syncLifecycleProvider =
    NotifierProvider<SyncLifecycleNotifier, void>(SyncLifecycleNotifier.new);
