import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leve_core/leve_core.dart';

import '../config/env.dart';
import '../network/bearer_interceptor.dart';
import '../network/refresh_interceptor.dart';
import '../../database/app_database.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/token_storage.dart';
import '../../features/caixa/data/caixa_repository.dart';
import '../../features/operacao/data/bootstrap_repository.dart';
import '../../features/auth/data/app_config_repository.dart';
import '../../features/printing/data/printer_service.dart';
import '../../features/printing/data/printer_storage.dart';
import '../../features/sync/data/sync_engine.dart';
import '../../features/tickets/data/ticket_repository.dart';

// ── SecureStorage ─────────────────────────────────────────────────────────

final secureStorageProvider = Provider<SecureStorage>((_) => SecureStorage());

// ── TokenStorage ──────────────────────────────────────────────────────────

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => TokenStorage(ref.read(secureStorageProvider)),
);

// ── API Client (Dio) ──────────────────────────────────────────────────────
// RefreshInterceptor precisa do Dio; Dio precisa do RefreshInterceptor.
// Solução: criar o Dio sem o refresh, depois adicioná-lo ao interceptors list.

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(tokenStorageProvider);
  final bearer  = BearerInterceptor(storage);

  final dio = ApiClientBase.create(
    baseUrl:        Env.apiBaseUrl,
    enableLogs:     Env.enableHttpLogs,
    connectTimeout: Env.connectTimeout,
    receiveTimeout: Env.receiveTimeout,
  );

  dio.interceptors.add(bearer);
  dio.interceptors.add(
    RefreshInterceptor(dio: dio, storage: storage, ref: ref),
  );

  return dio;
});

// ── AuthRepository ────────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    dio:     ref.read(dioProvider),
    storage: ref.read(tokenStorageProvider),
  ),
);

// ── AppDatabase (Drift) ───────────────────────────────────────────────────

final appDatabaseProvider = Provider<AppDatabase>((_) => AppDatabase());

// ── BootstrapRepository ───────────────────────────────────────────────────

final bootstrapRepositoryProvider = Provider<BootstrapRepository>(
  (ref) => BootstrapRepository(
    dio: ref.read(dioProvider),
    db:  ref.read(appDatabaseProvider),
  ),
);

// ── CaixaRepository ──────────────────────────────────────────────────────

final caixaRepositoryProvider = Provider<CaixaRepository>(
  (ref) => CaixaRepository(db: ref.read(appDatabaseProvider)),
);

// ── SyncEngine ────────────────────────────────────────────────────────────

final syncEngineProvider = Provider<SyncEngine>(
  (ref) => SyncEngine(
    db:      ref.read(appDatabaseProvider),
    dio:     ref.read(dioProvider),
    storage: ref.read(tokenStorageProvider),
  ),
);

// ── TicketRepository ──────────────────────────────────────────────────────

final ticketRepositoryProvider = Provider<TicketRepository>(
  (ref) => TicketRepository(db: ref.read(appDatabaseProvider)),
);

// ── PrinterStorage ────────────────────────────────────────────────────────

final printerStorageProvider = Provider<PrinterStorage>(
  (ref) => PrinterStorage(ref.read(secureStorageProvider)),
);

// ── PrinterService ────────────────────────────────────────────────────────

final printerServiceProvider = Provider<PrinterService>((_) => PrinterService());

// ── AppConfigRepository ───────────────────────────────────────────────────

final appConfigRepositoryProvider = Provider<AppConfigRepository>(
  (ref) => AppConfigRepository(dio: ref.read(dioProvider)),
);
