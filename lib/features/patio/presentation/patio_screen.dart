import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:leve_core/leve_core.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_patio_colors.dart';
import '../../../core/widgets/patio_bottom_nav.dart';
import '../../caixa/presentation/providers/caixa_provider.dart';
import '../../tickets/domain/ticket_model.dart';
import '../../tickets/presentation/providers/ticket_providers.dart';

class PatioScreen extends ConsumerWidget {
  const PatioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(ticketsAbertosProvider);
    final caixaAberta  = ref.watch(caixaSessaoNotifierProvider).maybeWhen(
      data: (v) => (v != null && v.isAberta) ? v : null,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: AppPatioColors.background,
      extendBody: true,
      bottomNavigationBar: const PatioBottomNav(currentIndex: 1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppPatioColors.secondary,
        title: ticketsAsync.maybeWhen(
          data: (list) => Text(
            'Pátio · ${list.length} veículo${list.length == 1 ? '' : 's'}',
          ),
          orElse: () => const Text('Ver Pátio'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: AppPatioColors.onSurfaceVariant,
            tooltip: 'Atualizar',
            onPressed: () => ref.invalidate(ticketsAbertosProvider),
          ),
        ],
      ),
      body: ticketsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppPatioColors.danger,
                size: 48,
              ),
              const SizedBox(height: 12),
              const Text(
                'Erro ao carregar pátio',
                style: TextStyle(
                  color: AppPatioColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(ticketsAbertosProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (tickets) {
          if (tickets.isEmpty) {
            return const _EmptyPatio();
          }
          return RefreshIndicator(
            color: AppPatioColors.secondary,
            onRefresh: () async => ref.invalidate(ticketsAbertosProvider),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: tickets.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _TicketCard(
                ticket: tickets[i],
                onTap: () {
                          if (caixaAberta == null) {
                            AppToast.error(context, 'Abra o caixa antes de registrar saídas');
                            return;
                          }
                          context.push(Routes.saidaDetalhe(tickets[i].id));
                        },
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyPatio extends StatelessWidget {
  const _EmptyPatio();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppPatioColors.info.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.garage_rounded,
            size: 40,
            color: AppPatioColors.info,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Pátio vazio',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppPatioColors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Nenhum veículo no pátio no momento',
          style: TextStyle(
            fontSize: 14,
            color: AppPatioColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

// ── Ticket card ───────────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final TicketModel ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tempo     = ticket.tempoPermanencia;
    final tempoStr  = _formatDuracao(tempo);
    final entradaStr = DateFormat('HH:mm').format(ticket.entrada);
    final tipoIcon  = _tipoIcon(ticket.tipoVeiculo);

    final alertaLongo = tempo.inHours >= 4;

    return Material(
      color: AppPatioColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: alertaLongo
                  ? AppPatioColors.warning.withValues(alpha: 0.4)
                  : AppPatioColors.outline,
            ),
          ),
          child: Row(
            children: [
              // ── Ícone tipo veículo ────────────────────────────────────────
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppPatioColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tipoIcon, color: AppPatioColors.info, size: 26),
              ),
              const SizedBox(width: 14),

              // ── Info principal ────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          ticket.placa,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppPatioColors.onSurface,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _TipoBadge(tipo: ticket.tipoVeiculo),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.login_rounded,
                          size: 13,
                          color: AppPatioColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Entrada: $entradaStr',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppPatioColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Tempo permanência ─────────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    tempoStr,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: alertaLongo
                          ? AppPatioColors.warning
                          : AppPatioColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppPatioColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDuracao(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h${m.toString().padLeft(2, '0')}m';
    return '${m}min';
  }

  static IconData _tipoIcon(String tipo) => switch (tipo.toLowerCase()) {
    'moto' || 'motocicleta' => Icons.two_wheeler_rounded,
    'caminhao' || 'caminhão' || 'truck' => Icons.local_shipping_rounded,
    'van' || 'utilitario' || 'utilitário' => Icons.airport_shuttle_rounded,
    _ => Icons.directions_car_rounded,
  };
}

// ── Tipo badge ────────────────────────────────────────────────────────────────

class _TipoBadge extends StatelessWidget {
  const _TipoBadge({required this.tipo});
  final String tipo;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppPatioColors.info.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      tipo.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppPatioColors.info,
        letterSpacing: 0.5,
      ),
    ),
  );
}
