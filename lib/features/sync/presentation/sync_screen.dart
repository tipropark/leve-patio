import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:leve_core/leve_core.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_patio_colors.dart';
import '../../../database/app_database.dart';
import 'providers/sync_provider.dart';

class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncAsync   = ref.watch(syncNotifierProvider);
    final falhosAsync = ref.watch(syncFalhosProvider);

    final sync       = syncAsync.maybeWhen(data: (s) => s, orElse: () => null);
    final isSyncing  = sync?.isSyncing ?? false;

    return Scaffold(
      backgroundColor: AppPatioColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppPatioColors.secondary,
        title: const Text('Sincronização'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppPatioColors.secondary,
          onRefresh: () async {
            await ref.read(syncNotifierProvider.notifier).trigger();
            ref.invalidate(syncFalhosProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Status hero ───────────────────────────────────────────────
              _StatusHero(sync: sync),
              const SizedBox(height: 16),

              // ── Sync now ──────────────────────────────────────────────────
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isSyncing
                        ? AppPatioColors.surfaceContainerHigh
                        : AppPatioColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: isSyncing
                      ? null
                      : () => ref.read(syncNotifierProvider.notifier).trigger(),
                  icon: isSyncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: Text(isSyncing ? 'Sincronizando…' : 'Sincronizar Agora'),
                ),
              ),
              const SizedBox(height: 24),

              // ── Itens com falha ───────────────────────────────────────────
              falhosAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (falhos) {
                  if (falhos.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 16,
                            color: AppPatioColors.danger,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${falhos.length} item${falhos.length > 1 ? 's' : ''} com falha',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppPatioColors.danger,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () async {
                              await ref
                                  .read(appDatabaseProvider)
                                  .syncDao
                                  .retryFalhos();
                              ref.invalidate(syncFalhosProvider);
                              ref.read(syncNotifierProvider.notifier).trigger();
                              if (context.mounted) {
                                AppToast.info(context, 'Tentando novamente…');
                              }
                            },
                            icon: const Icon(Icons.replay_rounded, size: 14),
                            label: const Text('Tentar novamente'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppPatioColors.warning,
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...falhos.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _SyncLogTile(item: item),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status hero ───────────────────────────────────────────────────────────────

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.sync});
  final SyncState? sync;

  @override
  Widget build(BuildContext context) {
    final pending = sync?.pendingCount ?? 0;
    final hasErr  = sync?.hasError ?? false;
    final syncing = sync?.isSyncing ?? false;
    final last    = sync?.lastSyncAt;

    final (Color heroColor, IconData heroIcon, String statusLabel) = switch (null) {
      _ when syncing  => (AppPatioColors.primary,  Icons.sync_rounded,         'Sincronizando…'),
      _ when hasErr   => (AppPatioColors.danger,   Icons.sync_problem_rounded, 'Erro na sincronização'),
      _ when pending > 0 => (AppPatioColors.warning, Icons.pending_rounded,   'Aguardando envio'),
      _               => (AppPatioColors.success,  Icons.check_circle_rounded, 'Tudo sincronizado'),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppPatioColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: heroColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: heroColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: syncing
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: heroColor,
                    ),
                  )
                : Icon(heroIcon, color: heroColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: heroColor,
                  ),
                ),
                if (pending > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$pending ${pending == 1 ? 'item pendente' : 'itens pendentes'}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppPatioColors.textSecondary,
                    ),
                  ),
                ],
                if (last != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Última sync: ${DateFormat('dd/MM HH:mm').format(last)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppPatioColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (pending > 0)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: heroColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  pending > 99 ? '99+' : '$pending',
                  style: TextStyle(
                    fontSize: pending > 9 ? 14 : 18,
                    fontWeight: FontWeight.w800,
                    color: heroColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Sync log tile ─────────────────────────────────────────────────────────────

class _SyncLogTile extends StatelessWidget {
  const _SyncLogTile({required this.item});
  final SyncLogData item;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppPatioColors.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppPatioColors.danger.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${item.entidade} · ${item.operacao}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppPatioColors.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              '${item.tentativas} tentativa${item.tentativas != 1 ? 's' : ''}',
              style: const TextStyle(
                fontSize: 11,
                color: AppPatioColors.textSecondary,
              ),
            ),
          ],
        ),
        if (item.erroUltimaTentativa != null) ...[
          const SizedBox(height: 4),
          Text(
            item.erroUltimaTentativa!,
            style: const TextStyle(
              fontSize: 12,
              color: AppPatioColors.danger,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    ),
  );
}
