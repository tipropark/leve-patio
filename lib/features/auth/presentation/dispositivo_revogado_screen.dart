import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/auth_provider.dart';

/// Exibida quando o servidor nega o refresh token (dispositivo revogado pelo admin).
class DispositivoRevogadoScreen extends ConsumerWidget {
  const DispositivoRevogadoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.block_rounded,
                  size: 72,
                  color: Color(0xFFC62828),
                ),
                const SizedBox(height: 20),
                Text(
                  'Acesso revogado',
                  style: tt.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Seu acesso a este dispositivo foi encerrado pelo administrador. '
                  'Entre em contato com o suporte.',
                  style: tt.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                FilledButton(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).onLoggedOut(),
                  child: const Text('Fazer novo login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
