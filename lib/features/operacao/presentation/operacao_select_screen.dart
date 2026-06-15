import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leve_core/leve_core.dart';

import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../domain/operacao_resumo.dart';
import '../../auth/domain/patio_user.dart';

class OperacaoSelectScreen extends ConsumerWidget {
  const OperacaoSelectScreen({
    super.key,
    required this.user,
    required this.operacoes,
    required this.isFirstLogin,
  });

  final PatioUser user;
  final List<OperacaoResumo> operacoes;
  final bool isFirstLogin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Selecionar Operação')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Olá, ${user.nome.split(' ').first}! Em qual pátio você está hoje?',
            style: tt.titleMedium,
          ),
          const SizedBox(height: 20),
          ...operacoes.map(
            (op) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    op.codigo.substring(0, op.codigo.length.clamp(0, 2)),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                title: Text(op.nome, style: tt.titleMedium),
                subtitle: Text('Código: ${op.codigo}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  try {
                    await ref
                        .read(authControllerProvider.notifier)
                        .selecionarOperacao(
                          user,
                          op.id,
                          isFirstLogin: isFirstLogin,
                        );
                  } catch (_) {
                    if (context.mounted) {
                      AppToast.error(context, 'Erro ao selecionar operação.');
                    }
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
