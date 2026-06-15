import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../../core/config/env.dart';
import '../../../database/app_database.dart';
import '../../../features/auth/data/token_storage.dart';
import 'sync_result.dart';

class SyncEngine {
  SyncEngine({
    required this.db,
    required this.dio,
    required this.storage,
  });

  final AppDatabase db;
  final Dio dio;
  final TokenStorage storage;

  /// Drains all due SyncLog entries. Guarantees: never drops an item without
  /// explicit server confirmation. After [Env.syncMaxTentativas] failures the
  /// item is moved to 'falhou' rather than deleted.
  Future<SyncResult> drain() async {
    final agora     = DateTime.now().millisecondsSinceEpoch;
    final pendentes = await db.syncDao.getPendentes(agora);

    if (pendentes.isEmpty) return const SyncResult(synced: 0, failed: 0);

    final operacaoId = await storage.readOperacaoId() ?? '';
    int synced = 0;
    int failed  = 0;

    for (final item in pendentes) {
      final ok = await _enviarItem(item, operacaoId);
      if (ok) {
        synced++;
      } else {
        failed++;
      }
    }

    return SyncResult(synced: synced, failed: failed);
  }

  Future<bool> _enviarItem(SyncLogData item, String operacaoId) async {
    try {
      final payload = jsonDecode(item.payload) as Map<String, dynamic>;

      await dio.post<void>(
        Env.syncUrl,
        data: {
          'app_id':      Env.appId,
          'operacao_id': operacaoId,
          'entidade':    item.entidade,
          'entidade_id': item.entidadeId,
          'operacao':    item.operacao,
          'payload':     payload,
        },
      );

      await db.syncDao.marcarSucesso(item.id);
      await _marcarEntidadeSincronizada(item.entidade, item.entidadeId);
      return true;
    } on DioException catch (e) {
      final isClientError = e.response?.statusCode != null &&
          e.response!.statusCode! >= 400 &&
          e.response!.statusCode! < 500;
      await _registrarFalha(item, _dioErrorMessage(e), immediate: isClientError);
      return false;
    } catch (e) {
      await _registrarFalha(item, e.toString());
      return false;
    }
  }

  Future<void> _registrarFalha(
    SyncLogData item,
    String msg, {
    bool immediate = false,
  }) async {
    final maxReached = item.tentativas >= Env.syncMaxTentativas;

    if (maxReached || immediate) {
      await db.syncDao.marcarFalhou(item.id, msg);
    } else {
      await db.syncDao.marcarErro(
        item.id,
        _proximaTentativa(item.tentativas),
        msg,
      );
    }
  }

  Future<void> _marcarEntidadeSincronizada(
    String entidade,
    String entidadeId,
  ) async {
    switch (entidade) {
      case 'ticket':
        await db.ticketsDao.marcarSincronizado(entidadeId);
      case 'caixa_sessao':
        await db.caixaDao.marcarSessaoSincronizada(entidadeId);
      case 'caixa_movimento':
        await db.caixaDao.marcarMovimentoSincronizado(entidadeId);
    }
  }

  /// Exposed for unit tests. Returns the next-retry epoch ms for [tentativas].
  static int proximaTentativaMs(int tentativas) {
    // Cap the exponent so 2^(exp+1) never overflows int64 (2^7 = 128 > 60).
    final safeExp = tentativas.clamp(0, 7);
    final minutos = math.min(math.pow(2, safeExp + 1).toInt(), 60);
    return DateTime.now()
        .add(Duration(minutes: minutos))
        .millisecondsSinceEpoch;
  }

  static int _proximaTentativa(int tentativas) => proximaTentativaMs(tentativas);

  static String _dioErrorMessage(DioException e) {
    if (e.response != null) return 'HTTP ${e.response!.statusCode}';
    return e.message ?? e.type.name;
  }
}
