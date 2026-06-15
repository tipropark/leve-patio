import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../sync/presentation/providers/sync_provider.dart';
import '../../domain/caixa_model.dart';

void _triggerSync(Ref ref) =>
    Future.microtask(() => ref.read(syncNotifierProvider.notifier).trigger());

class CaixaSessaoNotifier extends AsyncNotifier<CaixaModel?> {
  @override
  Future<CaixaModel?> build() async {
    final storage    = ref.read(tokenStorageProvider);
    final operacaoId = await storage.readOperacaoId();
    final user       = await storage.readUser();
    if (operacaoId == null || user == null) return null;
    return ref.read(caixaRepositoryProvider).getSessaoAberta(operacaoId, user.id);
  }

  Future<void> abrir({required double fundoCaixa}) async {
    state = const AsyncLoading();
    try {
      final storage    = ref.read(tokenStorageProvider);
      final operacaoId = await storage.readOperacaoId();
      final user       = await storage.readUser();

      if (operacaoId == null || user == null) {
        throw Exception('Sessão inválida. Faça login novamente.');
      }

      await ref.read(caixaRepositoryProvider).abrirCaixa(
        operacaoId:   operacaoId,
        operadorId:   user.id,
        operadorNome: user.nome,
        fundoCaixa:   fundoCaixa,
      );

      final sessao = await ref
          .read(caixaRepositoryProvider)
          .getSessaoAberta(operacaoId, user.id);
      state = AsyncData(sessao);
      _triggerSync(ref);
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  Future<void> registrarReceita({
    required double valor,
    required String descricao,
    required String formaPagamento,
  }) async {
    final sessao = switch (state) {
      AsyncData(:final value) when value != null => value,
      _ => null,
    };
    if (sessao == null) return;

    await ref.read(caixaRepositoryProvider).registrarReceita(
      caixaSessaoId:  sessao.id,
      valor:          valor,
      descricao:      descricao,
      formaPagamento: formaPagamento,
    );

    ref.invalidateSelf();
    _triggerSync(ref);
  }

  Future<void> registrarSangria({
    required double valor,
    required String descricao,
  }) async {
    final sessao = switch (state) {
      AsyncData(:final value) when value != null => value,
      _ => null,
    };
    if (sessao == null) return;

    await ref.read(caixaRepositoryProvider).registrarSangria(
      caixaSessaoId: sessao.id,
      valor:         valor,
      descricao:     descricao,
    );

    ref.invalidateSelf();
    _triggerSync(ref);
  }

  Future<void> registrarEntradaTicket({
    required String ticketId,
    required double valor,
    required String formaPagamento,
    required String placa,
  }) async {
    final sessao = switch (state) {
      AsyncData(:final value) when value != null => value,
      _ => null,
    };
    if (sessao == null) return;

    await ref.read(caixaRepositoryProvider).registrarEntradaTicket(
      caixaSessaoId:  sessao.id,
      ticketId:       ticketId,
      valor:          valor,
      formaPagamento: formaPagamento,
      placa:          placa,
    );

    ref.invalidateSelf();
    _triggerSync(ref);
  }
}

final caixaSessaoNotifierProvider =
    AsyncNotifierProvider<CaixaSessaoNotifier, CaixaModel?>(
  CaixaSessaoNotifier.new,
);

final movimentosProvider =
    FutureProvider.autoDispose.family<List<MovimentoModel>, String>(
  (ref, caixaSessaoId) =>
      ref.read(caixaRepositoryProvider).getMovimentos(caixaSessaoId),
);
