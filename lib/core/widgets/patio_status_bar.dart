import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../theme/app_patio_colors.dart';
import '../../features/operacao/presentation/providers/operacao_provider.dart';
import '../../features/sync/presentation/providers/sync_provider.dart';

/// Barra de status persistente no rodapé das telas principais.
/// Exibe: ID do pátio (4 dígitos), nome da operação e data/hora da última sync.
class PatioStatusBar extends ConsumerWidget {
  const PatioStatusBar({super.key});

  /// Gera um ID de 4 dígitos (1000–9999) estável a partir do UUID da operação.
  static int _patioId(String uuid) {
    final segment = uuid.replaceAll('-', '');
    var hash = 0;
    for (final c in segment.codeUnits) {
      hash = (hash * 31 + c) & 0xFFFFFFFF;
    }
    return (hash % 9000) + 1000;
  }

  static String _formatSyncTime(DateTime? dt) {
    if (dt == null) return '—';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60)  return 'agora';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}min atrás';
    if (diff.inHours < 24)    return DateFormat('HH:mm').format(dt);
    return DateFormat('dd/MM HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operacaoAsync = ref.watch(operacaoNotifierProvider);
    final syncAsync     = ref.watch(syncNotifierProvider);

    final operacao = operacaoAsync.maybeWhen(data: (v) => v, orElse: () => null);
    final syncState = syncAsync.maybeWhen(data: (v) => v, orElse: () => null);

    final patioIdStr = operacao != null
        ? _patioId(operacao.id).toString()
        : '—';

    final nomeDisplay = operacao != null
        ? operacao.nome.toUpperCase()
        : 'CARREGANDO...';

    // Prioriza lastSyncAt do notifier; fallback para sincronizadoEm do bootstrap
    final syncTime = syncState?.lastSyncAt ?? operacao?.sincronizadoEm;
    final syncStr  = syncState?.isSyncing == true
        ? 'sincronizando…'
        : _formatSyncTime(syncTime);

    final syncColor = syncState?.isSyncing == true
        ? AppPatioColors.warning
        : syncState?.hasError == true
            ? AppPatioColors.danger
            : AppPatioColors.syncOnline;

    return Material(
      color: const Color(0xFF0A0A0A),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // ── ID do pátio ──────────────────────────────────────────────
                _Chip(
                  icon: Icons.tag_rounded,
                  label: patioIdStr,
                  color: AppPatioColors.primary,
                ),
                const SizedBox(width: 10),

                // ── Nome do pátio ────────────────────────────────────────────
                Expanded(
                  child: Text(
                    nomeDisplay,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFAAAAAA),
                      letterSpacing: 0.3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                ),

                // ── Sync ─────────────────────────────────────────────────────
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (syncState?.isSyncing == true)
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: syncColor,
                        ),
                      )
                    else
                      Icon(Icons.sync_rounded, size: 12, color: syncColor),
                    const SizedBox(width: 4),
                    Text(
                      syncStr,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: syncColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}
