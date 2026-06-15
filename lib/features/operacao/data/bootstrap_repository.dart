import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/config/env.dart';
import '../../../database/app_database.dart';

class BootstrapRepository {
  BootstrapRepository({required this.dio, required this.db});

  final Dio dio;
  final AppDatabase db;

  Future<void> sincronizar(String operacaoId) async {
    final resp = await dio.get<Map<String, dynamic>>(
      Env.bootstrapUrl,
      queryParameters: {'operacao_id': operacaoId},
    );

    final data        = resp.data!;
    final opJson      = data['operacao'] as Map<String, dynamic>;
    final tarifasRaw  = data['tarifas']  as List<dynamic>;
    final clientesRaw = (data['clientes'] as List<dynamic>?) ?? const [];

    final configJson = jsonEncode({
      'tipos_veiculo':        opJson['tipos_veiculo'],
      'formas_pagamento':     opJson['formas_pagamento'],
      'motivos_isencao':      opJson['motivos_isencao'],
      'motivos_cancelamento': opJson['motivos_cancelamento'],
    });

    await db.operacaoDao.upsertCache(
      OperacaoCacheCompanion(
        operacaoId:     Value(opJson['id'] as String),
        nome:           Value(opJson['nome'] as String),
        codigo:         Value(opJson['codigo'] as String),
        qtdVagas:       Value(opJson['qtd_vagas'] as int),
        configJson:     Value(configJson),
        sincronizadoEm: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );

    final companions = tarifasRaw.map((raw) {
      final m         = raw as Map<String, dynamic>;
      final vigInicio = DateTime.parse(m['vigencia_inicio'] as String);
      final vigFim    = m['vigencia_fim'] != null
          ? DateTime.parse(m['vigencia_fim'] as String)
          : null;

      return TarifasCompanion(
        id:                     Value(m['id'] as String),
        operacaoId:             Value(operacaoId),
        nome:                   Value((m['nome'] as String?) ?? 'Padrão'),
        tipoVeiculo:            Value(m['tipo_veiculo'] as String),
        ordem:                  Value((m['ordem'] as int?) ?? 0),
        visivelOperador:        Value((m['visivel_operador'] as bool?) ?? true),
        fracaoInicialMinutos:   Value(m['fracao_inicial_minutos'] as int),
        fracaoInicialValor:     Value((m['fracao_inicial_valor'] as num).toDouble()),
        fracaoAdicionalMinutos: Value(m['fracao_adicional_minutos'] as int),
        fracaoAdicionalValor:   Value((m['fracao_adicional_valor'] as num).toDouble()),
        tetoDiaria:             Value((m['teto_diaria'] as num).toDouble()),
        toleranciaMinutos:      Value(m['tolerancia_minutos'] as int),
        pernoiteValor:          Value((m['pernoite_valor'] as num).toDouble()),
        pernoiteHoraInicio:     Value(m['pernoite_hora_inicio'] as int),
        pernoiteHoraFim:        Value(m['pernoite_hora_fim'] as int),
        vigenciaInicioEpoch:    Value(vigInicio.millisecondsSinceEpoch),
        vigenciaFimEpoch:       Value(vigFim?.millisecondsSinceEpoch),
      );
    }).toList();

    await db.operacaoDao.replaceTarifas(operacaoId, companions);

    // ── Clientes de livre passagem (mensalista/credenciado) ─────────────────
    final clientesComp = <PatioClientesCompanion>[];
    final placasComp    = <PatioClientePlacasCompanion>[];

    for (final raw in clientesRaw) {
      final m     = raw as Map<String, dynamic>;
      final id    = m['id'] as String;
      final plano = m['plano'] as Map<String, dynamic>?;
      final venc  = m['vencimento'] as String?;

      clientesComp.add(PatioClientesCompanion(
        id:              Value(id),
        operacaoId:      Value(operacaoId),
        nome:            Value(m['nome'] as String),
        planoId:         Value(plano?['id'] as String?),
        planoNome:       Value(plano?['nome'] as String?),
        planoTipo:       Value(plano?['tipo'] as String?),
        vagas:           Value((m['vagas'] as int?) ?? 1),
        vencimentoEpoch: Value(venc != null
            ? DateTime.parse('${venc}T00:00:00').millisecondsSinceEpoch
            : null),
        bloqueado:       Value((m['bloqueado'] as bool?) ?? false),
      ));

      for (final v in (m['veiculos'] as List<dynamic>? ?? const [])) {
        final vm = v as Map<String, dynamic>;
        placasComp.add(PatioClientePlacasCompanion(
          operacaoId: Value(operacaoId),
          placa:      Value((vm['placa'] as String).toUpperCase()),
          clienteId:  Value(id),
          descricao:  Value(vm['descricao'] as String?),
        ));
      }
    }

    await db.clientesDao.replaceClientes(operacaoId, clientesComp, placasComp);
  }
}
