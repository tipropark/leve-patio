import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../database/app_database.dart';
import '../domain/caixa_model.dart';

class CaixaRepository {
  CaixaRepository({required this.db});

  final AppDatabase db;

  Future<String> abrirCaixa({
    required String operacaoId,
    required String operadorId,
    required String operadorNome,
    required double fundoCaixa,
  }) async {
    final id    = const Uuid().v4();
    final agora = DateTime.now().millisecondsSinceEpoch;

    final payload = jsonEncode({
      'id':           id,
      'operacao_id':  operacaoId,
      'operador_id':  operadorId,
      'operador_nome': operadorNome,
      'fundo_caixa':  fundoCaixa,
      'status':       'aberta',
      'abertura_epoch': agora,
    });

    await db.transaction(() async {
      await db.caixaDao.abrirSessao(CaixaSessoesCompanion(
        id:            Value(id),
        operacaoId:    Value(operacaoId),
        operadorId:    Value(operadorId),
        operadorNome:  Value(operadorNome),
        fundoCaixa:    Value(fundoCaixa),
        status:        const Value('aberta'),
        aberturaEpoch: Value(agora),
        syncStatus:    const Value('pendente'),
      ));
      await db.syncDao.enqueue(SyncLogCompanion(
        entidade:   const Value('caixa_sessao'),
        entidadeId: Value(id),
        operacao:   const Value('create'),
        payload:    Value(payload),
        criadoEm:   Value(agora),
      ));
    });

    return id;
  }

  Future<CaixaModel?> getSessaoAberta(
    String operacaoId,
    String operadorId,
  ) async {
    final row = await db.caixaDao.getSessaoAberta(operacaoId, operadorId);
    return row != null ? _toModel(row) : null;
  }

  Future<CaixaModel?> getSessaoById(String id) async {
    final row = await db.caixaDao.getSessaoById(id);
    return row != null ? _toModel(row) : null;
  }

  Future<void> registrarReceita({
    required String caixaSessaoId,
    required double valor,
    required String descricao,
    required String formaPagamento,
  }) async {
    final id    = const Uuid().v4();
    final agora = DateTime.now().millisecondsSinceEpoch;

    final payload = jsonEncode({
      'id':              id,
      'caixa_sessao_id': caixaSessaoId,
      'tipo':            'receita',
      'valor':           valor,
      'descricao':       descricao,
      'forma_pagamento': formaPagamento,
      'criado_em':       agora,
    });

    await db.transaction(() async {
      await db.caixaDao.inserirMovimento(CaixaMovimentosCompanion(
        id:             Value(id),
        caixaSessaoId:  Value(caixaSessaoId),
        tipo:           const Value('receita'),
        valor:          Value(valor),
        descricao:      Value(descricao),
        formaPagamento: Value(formaPagamento),
        criadoEm:       Value(agora),
        syncStatus:     const Value('pendente'),
      ));

      final row = await db.caixaDao.getSessaoById(caixaSessaoId);
      if (row != null) {
        await db.caixaDao.atualizarSessao(
          caixaSessaoId,
          CaixaSessoesCompanion(
            totalEntradas: Value(row.totalEntradas + valor),
            syncStatus:    const Value('pendente'),
          ),
        );
      }

      await db.syncDao.enqueue(SyncLogCompanion(
        entidade:   const Value('caixa_movimento'),
        entidadeId: Value(id),
        operacao:   const Value('create'),
        payload:    Value(payload),
        criadoEm:   Value(agora),
      ));
    });
  }

  Future<void> registrarSangria({
    required String caixaSessaoId,
    required double valor,
    required String descricao,
  }) async {
    final id    = const Uuid().v4();
    final agora = DateTime.now().millisecondsSinceEpoch;

    final payload = jsonEncode({
      'id':             id,
      'caixa_sessao_id': caixaSessaoId,
      'tipo':           'sangria',
      'valor':          valor,
      'descricao':      descricao,
      'criado_em':      agora,
    });

    await db.transaction(() async {
      await db.caixaDao.inserirMovimento(CaixaMovimentosCompanion(
        id:            Value(id),
        caixaSessaoId: Value(caixaSessaoId),
        tipo:          const Value('sangria'),
        valor:         Value(valor),
        descricao:     Value(descricao),
        criadoEm:      Value(agora),
        syncStatus:    const Value('pendente'),
      ));

      final row = await db.caixaDao.getSessaoById(caixaSessaoId);
      if (row != null) {
        await db.caixaDao.atualizarSessao(
          caixaSessaoId,
          CaixaSessoesCompanion(
            totalSangrias: Value(row.totalSangrias + valor),
            syncStatus:    const Value('pendente'),
          ),
        );
      }

      await db.syncDao.enqueue(SyncLogCompanion(
        entidade:   const Value('caixa_movimento'),
        entidadeId: Value(id),
        operacao:   const Value('create'),
        payload:    Value(payload),
        criadoEm:   Value(agora),
      ));
    });
  }

  Future<void> registrarEntradaTicket({
    required String caixaSessaoId,
    required String ticketId,
    required double valor,
    required String formaPagamento,
    required String placa,
  }) async {
    final id    = const Uuid().v4();
    final agora = DateTime.now().millisecondsSinceEpoch;

    final payload = jsonEncode({
      'id':              id,
      'caixa_sessao_id': caixaSessaoId,
      'tipo':            'entrada',
      'valor':           valor,
      'descricao':       'Ticket $placa',
      'ticket_id':       ticketId,
      'forma_pagamento': formaPagamento,
      'criado_em':       agora,
    });

    await db.transaction(() async {
      await db.caixaDao.inserirMovimento(CaixaMovimentosCompanion(
        id:             Value(id),
        caixaSessaoId:  Value(caixaSessaoId),
        tipo:           const Value('entrada'),
        valor:          Value(valor),
        descricao:      Value('Ticket $placa'),
        ticketId:       Value(ticketId),
        formaPagamento: Value(formaPagamento),
        criadoEm:       Value(agora),
        syncStatus:     const Value('pendente'),
      ));

      final row = await db.caixaDao.getSessaoById(caixaSessaoId);
      if (row != null) {
        await db.caixaDao.atualizarSessao(
          caixaSessaoId,
          CaixaSessoesCompanion(
            totalEntradas: Value(row.totalEntradas + valor),
            syncStatus:    const Value('pendente'),
          ),
        );
      }

      await db.syncDao.enqueue(SyncLogCompanion(
        entidade:   const Value('caixa_movimento'),
        entidadeId: Value(id),
        operacao:   const Value('create'),
        payload:    Value(payload),
        criadoEm:   Value(agora),
      ));
    });
  }

  Future<FechamentoResult> fecharCaixa({
    required String caixaSessaoId,
    required double totalContado,
    String? observacao,
  }) async {
    final row = await db.caixaDao.getSessaoById(caixaSessaoId);
    if (row == null) throw Exception('Sessão de caixa não encontrada');

    final totalCalculado =
        row.fundoCaixa + row.totalEntradas - row.totalSangrias;
    final divergencia = totalContado - totalCalculado;
    final agora = DateTime.now().millisecondsSinceEpoch;

    final payload = jsonEncode({
      'status':                'fechada',
      'total_fechamento':      totalContado,
      'fechamento_epoch':      agora,
      'observacao_fechamento': observacao,
    });

    await db.transaction(() async {
      await db.caixaDao.atualizarSessao(
        caixaSessaoId,
        CaixaSessoesCompanion(
          status:               const Value('fechada'),
          totalFechamento:      Value(totalContado),
          fechamentoEpoch:      Value(agora),
          observacaoFechamento: Value(observacao),
          syncStatus:           const Value('pendente'),
        ),
      );
      await db.syncDao.enqueue(SyncLogCompanion(
        entidade:   const Value('caixa_sessao'),
        entidadeId: Value(caixaSessaoId),
        operacao:   const Value('update'),
        payload:    Value(payload),
        criadoEm:   Value(agora),
      ));
    });

    return FechamentoResult(
      totalCalculado: totalCalculado,
      totalContado:   totalContado,
      divergencia:    divergencia,
    );
  }

  Future<List<MovimentoModel>> getMovimentos(String caixaSessaoId) async {
    final rows = await db.caixaDao.getMovimentosBySessao(caixaSessaoId);

    // Collect unique ticket IDs referenced by movements.
    final ticketIds = rows
        .where((r) => r.ticketId != null)
        .map((r) => r.ticketId!)
        .toSet()
        .toList();

    // Map ticketId → tabelaPrecoId.
    final Map<String, String?> tpIdByTicket = {};
    if (ticketIds.isNotEmpty) {
      final ticketRows = await (db.select(db.tickets)
            ..where((t) => t.id.isIn(ticketIds)))
          .get();
      for (final t in ticketRows) {
        tpIdByTicket[t.id] = t.tabelaPrecoId;
      }
    }

    // Map tabelaPrecoId → nome.
    final tarifaIds = tpIdByTicket.values.whereType<String>().toSet().toList();
    final Map<String, String> nomeById = {};
    if (tarifaIds.isNotEmpty) {
      final tarifaRows = await (db.select(db.tarifas)
            ..where((t) => t.id.isIn(tarifaIds)))
          .get();
      for (final t in tarifaRows) {
        nomeById[t.id] = t.nome;
      }
    }

    return rows.map((row) {
      String? tabelaPrecoNome;
      if (row.ticketId != null) {
        final tpId = tpIdByTicket[row.ticketId];
        if (tpId != null) tabelaPrecoNome = nomeById[tpId];
      }
      return _toMovimentoModel(row, tabelaPrecoNome: tabelaPrecoNome);
    }).toList();
  }

  static CaixaModel _toModel(CaixaSessoe row) => CaixaModel(
    id:                   row.id,
    operacaoId:           row.operacaoId,
    operadorId:           row.operadorId,
    operadorNome:         row.operadorNome,
    fundoCaixa:           row.fundoCaixa,
    totalEntradas:        row.totalEntradas,
    totalSangrias:        row.totalSangrias,
    totalFechamento:      row.totalFechamento,
    status:               row.status,
    abertura:             DateTime.fromMillisecondsSinceEpoch(row.aberturaEpoch),
    fechamento:           row.fechamentoEpoch != null
        ? DateTime.fromMillisecondsSinceEpoch(row.fechamentoEpoch!)
        : null,
    observacaoFechamento: row.observacaoFechamento,
    syncStatus:           row.syncStatus,
  );

  static MovimentoModel _toMovimentoModel(
    CaixaMovimento row, {
    String? tabelaPrecoNome,
  }) =>
      MovimentoModel(
        id:              row.id,
        caixaSessaoId:   row.caixaSessaoId,
        tipo:            row.tipo,
        valor:           row.valor,
        descricao:       row.descricao,
        ticketId:        row.ticketId,
        formaPagamento:  row.formaPagamento,
        tabelaPrecoNome: tabelaPrecoNome,
        criadoEm:        DateTime.fromMillisecondsSinceEpoch(row.criadoEm),
      );
}
