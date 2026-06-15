import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/operacao_cache_table.dart';
import 'tables/tarifas_table.dart';
import 'tables/tickets_table.dart';
import 'tables/caixa_sessoes_table.dart';
import 'tables/caixa_movimentos_table.dart';
import 'tables/sync_log_table.dart';
import 'tables/patio_clientes_table.dart';
import 'tables/patio_cliente_placas_table.dart';

part 'app_database.g.dart';
part 'daos/operacao_dao.dart';
part 'daos/tickets_dao.dart';
part 'daos/caixa_dao.dart';
part 'daos/sync_dao.dart';
part 'daos/clientes_dao.dart';

@DriftDatabase(
  tables: [
    OperacaoCache,
    Tarifas,
    Tickets,
    CaixaSessoes,
    CaixaMovimentos,
    SyncLog,
    PatioClientes,
    PatioClientePlacas,
  ],
  daos: [OperacaoDao, TicketsDao, CaixaDao, SyncDao, ClientesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // Para testes: permite injetar um executor diferente.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v2: tabelas de preço nomeadas + tabelaPrecoId no ticket
        await m.addColumn(tarifas, tarifas.nome);
        await m.addColumn(tarifas, tarifas.ordem);
        await m.addColumn(tarifas, tarifas.visivelOperador);
        await m.addColumn(tickets, tickets.tabelaPrecoId);
      }
      if (from < 3) {
        // v3: clientes de livre passagem + vínculo no ticket
        await m.createTable(patioClientes);
        await m.createTable(patioClientePlacas);
        await m.addColumn(tickets, tickets.clienteId);
        await m.addColumn(tickets, tickets.planoId);
        await m.addColumn(tickets, tickets.origem);
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'leve_patio.db'));
    return NativeDatabase.createInBackground(file);
  });
}
