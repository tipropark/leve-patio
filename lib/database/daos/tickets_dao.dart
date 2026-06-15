part of '../app_database.dart';

@DriftAccessor(tables: [Tickets])
class TicketsDao extends DatabaseAccessor<AppDatabase>
    with _$TicketsDaoMixin {
  TicketsDao(super.db);

  Future<void> inserir(TicketsCompanion t) => into(tickets).insert(t);

  Future<Ticket?> getById(String id) =>
      (select(tickets)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Ticket>> getAbertos(String operacaoId) =>
      (select(tickets)
            ..where(
              (t) =>
                  t.operacaoId.equals(operacaoId) & t.status.equals('aberto'),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.entradaEpoch)]))
          .get();

  Future<Ticket?> getAbertoByPlaca(String operacaoId, String placa) =>
      (select(tickets)
            ..where(
              (t) =>
                  t.operacaoId.equals(operacaoId) &
                  t.placa.equals(placa) &
                  t.status.equals('aberto'),
            ))
          .getSingleOrNull();

  Future<void> atualizar(String id, TicketsCompanion c) =>
      (update(tickets)..where((t) => t.id.equals(id))).write(c);

  /// Quantos veículos do cliente estão no pátio agora (tickets abertos).
  /// Usado para validar o limite de vagas na entrada.
  Future<int> contarAbertosPorCliente(
    String operacaoId,
    String clienteId,
  ) async {
    final rows = await (select(tickets)
          ..where((t) =>
              t.operacaoId.equals(operacaoId) &
              t.clienteId.equals(clienteId) &
              t.status.equals('aberto')))
        .get();
    return rows.length;
  }

  Future<List<Ticket>> getPendentesSync() =>
      (select(tickets)..where((t) => t.syncStatus.equals('pendente'))).get();

  Future<void> marcarSincronizado(String id) =>
      (update(tickets)..where((t) => t.id.equals(id)))
          .write(const TicketsCompanion(syncStatus: Value('sincronizado')));
}
