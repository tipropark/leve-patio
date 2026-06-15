import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../database/app_database.dart';
import '../domain/ticket_model.dart';
import '../domain/reconhecimento_cliente.dart';

class TicketRepository {
  TicketRepository({required this.db});

  final AppDatabase db;

  /// Reconhece a placa contra o cache local de clientes de livre passagem.
  /// Retorna null quando a placa não pertence a nenhum cliente (fluxo avulso).
  Future<ReconhecimentoCliente?> reconhecerPlaca(
    String operacaoId,
    String placa,
  ) async {
    final cliente = await db.clientesDao
        .getClienteByPlaca(operacaoId, placa.trim().toUpperCase());
    if (cliente == null) return null;

    final ocupadas =
        await db.ticketsDao.contarAbertosPorCliente(operacaoId, cliente.id);

    final StatusReconhecimento status;
    if (cliente.bloqueado) {
      status = StatusReconhecimento.bloqueado;
    } else if (_vencido(cliente.vencimentoEpoch)) {
      status = StatusReconhecimento.vencido;
    } else if (ocupadas >= cliente.vagas) {
      status = StatusReconhecimento.vagasEsgotadas;
    } else {
      status = StatusReconhecimento.livrePassagem;
    }

    return ReconhecimentoCliente(
      clienteId:     cliente.id,
      nome:          cliente.nome,
      planoId:       cliente.planoId,
      planoNome:     cliente.planoNome,
      planoTipo:     cliente.planoTipo,
      vagas:         cliente.vagas,
      vagasOcupadas: ocupadas,
      status:        status,
    );
  }

  /// Vencido = data de vencimento anterior ao início de hoje.
  /// (vencimento no próprio dia ainda é válido.)
  static bool _vencido(int? vencimentoEpoch) {
    if (vencimentoEpoch == null) return false;
    final agora = DateTime.now();
    final inicioHoje =
        DateTime(agora.year, agora.month, agora.day).millisecondsSinceEpoch;
    return vencimentoEpoch < inicioHoje;
  }

  Future<String> registrarEntrada({
    required String placa,
    required String tipoVeiculo,
    required String operacaoId,
    required String operadorId,
    String? caixaSessaoId,
    String? tarifaId,
    String? clienteId,
    String? planoId,
    String origem = 'avulso',
  }) async {
    final id    = const Uuid().v4();
    final agora = DateTime.now().millisecondsSinceEpoch;
    final placaNorm = placa.trim().toUpperCase();

    final payload = jsonEncode({
      'id':              id,
      'operacao_id':     operacaoId,
      'placa':           placaNorm,
      'tipo_veiculo':    tipoVeiculo,
      'entrada_epoch':   agora,
      'status':          'aberto',
      'operador_id':     operadorId,
      'caixa_sessao_id': caixaSessaoId,
      'tabela_preco_id': tarifaId,
      'cliente_id':      clienteId,
      'plano_id':        planoId,
      'origem':          origem,
      'criado_em':       agora,
      'atualizado_em':   agora,
    });

    await db.transaction(() async {
      await db.ticketsDao.inserir(TicketsCompanion(
        id:            Value(id),
        operacaoId:    Value(operacaoId),
        placa:         Value(placaNorm),
        tipoVeiculo:   Value(tipoVeiculo),
        entradaEpoch:  Value(agora),
        status:        const Value('aberto'),
        operadorId:    Value(operadorId),
        caixaSessaoId: Value(caixaSessaoId),
        tabelaPrecoId: Value(tarifaId),
        clienteId:     Value(clienteId),
        planoId:       Value(planoId),
        origem:        Value(origem),
        syncStatus:    const Value('pendente'),
        criadoEm:      Value(agora),
        atualizadoEm:  Value(agora),
      ));
      await db.syncDao.enqueue(SyncLogCompanion(
        entidade:   const Value('ticket'),
        entidadeId: Value(id),
        operacao:   const Value('create'),
        payload:    Value(payload),
        criadoEm:   Value(agora),
      ));
    });

    return id;
  }

  Future<void> fecharTicket({
    required String ticketId,
    required double valorCalculado,
    required double valorCobrado,
    required String formaPagamento,
    String? motivoIsencao,
    String? tabelaPrecoId,
  }) async {
    final existing = await db.ticketsDao.getById(ticketId);
    if (existing == null) throw Exception('Ticket não encontrado');
    if (existing.status != 'aberto') {
      throw Exception('Ticket já foi fechado');
    }

    final agora = DateTime.now().millisecondsSinceEpoch;

    final payload = jsonEncode({
      'saida_epoch':      agora,
      'valor_calculado':  valorCalculado,
      'valor_cobrado':    valorCobrado,
      'forma_pagamento':  formaPagamento,
      'motivo_isencao':   motivoIsencao,
      'tabela_preco_id':  tabelaPrecoId,
      'status':           'fechado',
      'atualizado_em':    agora,
    });

    await db.transaction(() async {
      await db.ticketsDao.atualizar(
        ticketId,
        TicketsCompanion(
          saidaEpoch:     Value(agora),
          valorCalculado: Value(valorCalculado),
          valorCobrado:   Value(valorCobrado),
          formaPagamento: Value(formaPagamento),
          motivoIsencao:  Value(motivoIsencao),
          tabelaPrecoId:  Value(tabelaPrecoId),
          status:         const Value('fechado'),
          syncStatus:     const Value('pendente'),
          atualizadoEm:   Value(agora),
        ),
      );
      await db.syncDao.enqueue(SyncLogCompanion(
        entidade:   const Value('ticket'),
        entidadeId: Value(ticketId),
        operacao:   const Value('update'),
        payload:    Value(payload),
        criadoEm:   Value(agora),
      ));
    });
  }

  Future<List<TicketModel>> getTicketsAbertos(String operacaoId) async {
    final rows = await db.ticketsDao.getAbertos(operacaoId);
    return rows.map(_toModel).toList();
  }

  Future<TicketModel?> buscarAbertoByPlaca(
    String operacaoId,
    String placa,
  ) async {
    final row = await db.ticketsDao.getAbertoByPlaca(
      operacaoId,
      placa.trim().toUpperCase(),
    );
    return row != null ? _toModel(row) : null;
  }

  Future<TicketModel?> getById(String id) async {
    final row = await db.ticketsDao.getById(id);
    return row != null ? _toModel(row) : null;
  }

  static TicketModel _toModel(Ticket row) => TicketModel(
    id:             row.id,
    operacaoId:     row.operacaoId,
    placa:          row.placa,
    tipoVeiculo:    row.tipoVeiculo,
    entrada:        DateTime.fromMillisecondsSinceEpoch(row.entradaEpoch),
    saida:          row.saidaEpoch != null
        ? DateTime.fromMillisecondsSinceEpoch(row.saidaEpoch!)
        : null,
    valorCalculado: row.valorCalculado,
    valorCobrado:   row.valorCobrado,
    formaPagamento: row.formaPagamento,
    motivoIsencao:  row.motivoIsencao,
    status:         row.status,
    operadorId:     row.operadorId,
    caixaSessaoId:  row.caixaSessaoId,
    tabelaPrecoId:  row.tabelaPrecoId,
    clienteId:      row.clienteId,
    planoId:        row.planoId,
    origem:         row.origem,
    syncStatus:     row.syncStatus,
  );
}
