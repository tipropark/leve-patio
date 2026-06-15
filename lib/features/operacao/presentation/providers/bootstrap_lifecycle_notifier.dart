import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import 'operacao_provider.dart';

/// Escuta mudanças de auth e dispara o bootstrap ao entrar em AuthLoggedIn.
///
/// Deve ser instanciado uma única vez na raiz do app via ref.watch.
class BootstrapLifecycleNotifier extends Notifier<void> {
  @override
  void build() {
    ref.listen(authControllerProvider, (prev, next) {
      if (next is AuthLoggedIn) {
        // Fire-and-forget; erros são absorvidos no OperacaoNotifier.
        ref.read(operacaoNotifierProvider.notifier).bootstrap();
      }
    });
  }
}

final bootstrapLifecycleProvider =
    NotifierProvider<BootstrapLifecycleNotifier, void>(
  BootstrapLifecycleNotifier.new,
);
