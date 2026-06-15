import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../data/sync_result.dart';

enum SyncStatus { idle, syncing, error }

class SyncState {
  const SyncState({
    required this.status,
    required this.pendingCount,
    this.lastSyncAt,
    this.lastResult,
  });

  final SyncStatus status;
  final int pendingCount;
  final DateTime? lastSyncAt;
  final SyncResult? lastResult;

  bool get isSyncing => status == SyncStatus.syncing;
  bool get hasError  => status == SyncStatus.error;

  SyncState copyWith({
    SyncStatus? status,
    int? pendingCount,
    DateTime? lastSyncAt,
    SyncResult? lastResult,
  }) =>
      SyncState(
        status:       status       ?? this.status,
        pendingCount: pendingCount ?? this.pendingCount,
        lastSyncAt:   lastSyncAt   ?? this.lastSyncAt,
        lastResult:   lastResult   ?? this.lastResult,
      );
}

class SyncNotifier extends AsyncNotifier<SyncState> {
  @override
  Future<SyncState> build() async {
    final count =
        await ref.read(appDatabaseProvider).syncDao.countPendentes();
    return SyncState(status: SyncStatus.idle, pendingCount: count);
  }

  Future<void> trigger() async {
    final current = switch (state) {
      AsyncData(:final value) => value,
      _ => const SyncState(status: SyncStatus.idle, pendingCount: 0),
    };
    if (current.isSyncing) return;

    state = AsyncData(current.copyWith(status: SyncStatus.syncing));

    try {
      final result   = await ref.read(syncEngineProvider).drain();
      final newCount =
          await ref.read(appDatabaseProvider).syncDao.countPendentes();

      state = AsyncData(SyncState(
        status:       result.hasErrors ? SyncStatus.error : SyncStatus.idle,
        pendingCount: newCount,
        lastSyncAt:   DateTime.now(),
        lastResult:   result,
      ));
    } catch (_) {
      final cur = switch (state) {
        AsyncData(:final value) => value,
        _ => const SyncState(status: SyncStatus.idle, pendingCount: 0),
      };
      state = AsyncData(cur.copyWith(status: SyncStatus.error));
    }
  }

  Future<void> refreshCount() async {
    final count =
        await ref.read(appDatabaseProvider).syncDao.countPendentes();
    final cur = switch (state) {
      AsyncData(:final value) => value,
      _ => const SyncState(status: SyncStatus.idle, pendingCount: 0),
    };
    state = AsyncData(cur.copyWith(pendingCount: count));
  }
}

final syncNotifierProvider =
    AsyncNotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);

final syncFalhosProvider = FutureProvider.autoDispose(
  (ref) => ref.read(appDatabaseProvider).syncDao.getFalhos(),
);
