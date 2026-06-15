import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../domain/operacao_model.dart';
import '../../domain/tarifa_config.dart';

class OperacaoNotifier extends AsyncNotifier<OperacaoModel?> {
  @override
  Future<OperacaoModel?> build() async {
    final operacaoId =
        await ref.read(tokenStorageProvider).readOperacaoId();
    if (operacaoId == null) return null;
    return _lerCache(operacaoId);
  }

  Future<OperacaoModel?> _lerCache(String operacaoId) async {
    final db    = ref.read(appDatabaseProvider);
    final cache = await db.operacaoDao.getCacheByOperacaoId(operacaoId);
    if (cache == null) return null;

    final tarifasRows = await db.operacaoDao.getTarifasByOperacaoId(operacaoId);
    final config      = jsonDecode(cache.configJson) as Map<String, dynamic>;

    final tarifas = tarifasRows.map((r) {
      return TarifaConfig(
        id:                     r.id,
        operacaoId:             r.operacaoId,
        nome:                   r.nome,
        tipoVeiculo:            r.tipoVeiculo,
        ordem:                  r.ordem,
        visivelOperador:        r.visivelOperador,
        fracaoInicialMinutos:   r.fracaoInicialMinutos,
        fracaoInicialValor:     r.fracaoInicialValor,
        fracaoAdicionalMinutos: r.fracaoAdicionalMinutos,
        fracaoAdicionalValor:   r.fracaoAdicionalValor,
        tetoDiaria:             r.tetoDiaria,
        toleranciaMinutos:      r.toleranciaMinutos,
        pernoiteValor:          r.pernoiteValor,
        pernoiteHoraInicio:     r.pernoiteHoraInicio,
        pernoiteHoraFim:        r.pernoiteHoraFim,
        vigenciaInicio:
            DateTime.fromMillisecondsSinceEpoch(r.vigenciaInicioEpoch),
        vigenciaFim: r.vigenciaFimEpoch != null
            ? DateTime.fromMillisecondsSinceEpoch(r.vigenciaFimEpoch!)
            : null,
      );
    }).toList();

    return OperacaoModel(
      id:                  cache.operacaoId,
      nome:                cache.nome,
      codigo:              cache.codigo,
      qtdVagas:            cache.qtdVagas,
      tiposVeiculo:        List<String>.from((config['tipos_veiculo']        as List?) ?? []),
      formasPagamento:     List<String>.from((config['formas_pagamento']     as List?) ?? []),
      motivosIsencao:      List<String>.from((config['motivos_isencao']      as List?) ?? []),
      motivosCancelamento: List<String>.from((config['motivos_cancelamento'] as List?) ?? []),
      tarifas:             tarifas,
      sincronizadoEm:
          DateTime.fromMillisecondsSinceEpoch(cache.sincronizadoEm),
    );
  }

  /// Busca bootstrap da API e persiste em cache. Fire-and-forget no background.
  Future<void> bootstrap() async {
    state = const AsyncLoading();
    try {
      final operacaoId =
          await ref.read(tokenStorageProvider).readOperacaoId();
      if (operacaoId == null) {
        state = const AsyncData(null);
        return;
      }
      await ref.read(bootstrapRepositoryProvider).sincronizar(operacaoId);
      state = AsyncData(await _lerCache(operacaoId));
    } catch (e, s) {
      // Mantém cache anterior em erro; propaga AsyncError só se não houver cache
      final operacaoId =
          await ref.read(tokenStorageProvider).readOperacaoId();
      final cached =
          operacaoId != null ? await _lerCache(operacaoId) : null;
      state = cached != null ? AsyncData(cached) : AsyncError(e, s);
    }
  }
}

final operacaoNotifierProvider =
    AsyncNotifierProvider<OperacaoNotifier, OperacaoModel?>(
  OperacaoNotifier.new,
);
