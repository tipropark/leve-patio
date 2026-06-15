import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:leve_core/leve_core.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_patio_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/patio_background.dart';
import '../../../core/widgets/patio_bottom_nav.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/caixa/domain/caixa_model.dart';
import '../../../features/caixa/presentation/providers/caixa_provider.dart';
import '../../../features/operacao/presentation/providers/operacao_provider.dart';
import '../../../features/sync/presentation/providers/sync_provider.dart';
import '../../../features/sync/presentation/sync_indicator.dart';
import '../../../features/tickets/presentation/providers/ticket_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState     = ref.watch(authControllerProvider);
    final operacaoAsync = ref.watch(operacaoNotifierProvider);
    final caixaAsync    = ref.watch(caixaSessaoNotifierProvider);
    final ticketsAsync  = ref.watch(ticketsAbertosProvider);

    final nomeUsuario = switch (authState) {
      AuthLoggedIn(:final user) => user.nome.split(' ').first,
      _ => 'Operador',
    };

    final syncAsync     = ref.watch(syncNotifierProvider);

    final caixaAberta = caixaAsync.maybeWhen(
      data: (v) => (v != null && v.isAberta) ? v : null,
      orElse: () => null,
    );

    final totalNoPatio = ticketsAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    final operacaoNome = operacaoAsync.maybeWhen(
      data: (op) => op?.nome ?? 'Leve Pátio',
      orElse: () => 'Leve Pátio',
    );

    final syncState = syncAsync.maybeWhen(data: (s) => s, orElse: () => null);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor:          Colors.transparent,
        statusBarBrightness:     Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppPatioColors.background,
        extendBody: true,
        bottomNavigationBar: const PatioBottomNav(currentIndex: 0),
        body: PatioBackground(
          child: Column(
            children: [
              // ── AppBar glass ───────────────────────────────────────────────
              _GlassAppBar(
                title: operacaoNome,
                nomeUsuario: nomeUsuario,
              ),

              // ── Conteúdo scrollável ────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status card
                      _StatusCard(
                        caixaAberta:  caixaAberta,
                        caixaLoading: caixaAsync is AsyncLoading,
                        totalNoPatio: totalNoPatio,
                        syncState:    syncState,
                      ),
                      const SizedBox(height: 20),

                      // Bento grid 2x2
                      _BentoGrid(
                        caixaAberta:  caixaAberta,
                        totalNoPatio: totalNoPatio,
                        onEntrada:    () => context.push(Routes.entrada),
                        onSaida: () {
                          if (caixaAberta == null) {
                            AppToast.error(context, 'Abra o caixa antes de registrar saídas');
                            return;
                          }
                          context.push(Routes.saida);
                        },
                        onCaixa:      () => context.push(Routes.aberturaCaixa),
                        onPatio:      () => context.push(Routes.patio),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── AppBar com glassmorphism ────────────────────────────────────────────────

class _GlassAppBar extends StatelessWidget {
  const _GlassAppBar({required this.title, required this.nomeUsuario});

  final String title;
  final String nomeUsuario;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xCC011230),
            border: Border(bottom: BorderSide(color: AppPatioColors.glassBorder)),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    // Ícone de seta (só para consistência visual — home não navega para trás)
                    const SizedBox(width: 48),

                    // Título
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: AppPatioColors.secondary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Sync indicator
                    const SyncIndicator(),

                    // Ajustes
                    IconButton(
                      icon: const Icon(Icons.settings_rounded, color: AppPatioColors.onSurfaceVariant),
                      onPressed: () => context.push(Routes.ajustes),
                      tooltip: 'Ajustes',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Status card (com timer para atualizar tempo relativo do sync) ────────────

class _StatusCard extends StatefulWidget {
  const _StatusCard({
    required this.caixaAberta,
    required this.caixaLoading,
    required this.totalNoPatio,
    required this.syncState,
  });

  final CaixaModel? caixaAberta;
  final bool        caixaLoading;
  final int         totalNoPatio;
  final SyncState?  syncState;

  @override
  State<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<_StatusCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Atualiza o texto relativo ("X min atrás") a cada 30 segundos
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static String _syncLabel(SyncState? sync) {
    if (sync == null) return '—';
    if (sync.isSyncing) return 'Sincronizando…';
    final dt = sync.lastSyncAt;
    if (dt == null) return 'Nunca sincronizado';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'Agora há pouco';
    if (diff.inMinutes < 60)  return 'Há ${diff.inMinutes}min';
    if (diff.inHours   < 24)  return 'Há ${diff.inHours}h';
    return DateFormat('dd/MM HH:mm').format(dt);
  }

  static Color _syncColor(SyncState? sync) {
    if (sync == null) return AppPatioColors.outline;
    if (sync.isSyncing) return AppPatioColors.secondary;
    if (sync.hasError)  return AppPatioColors.danger;
    if (sync.lastSyncAt == null) return AppPatioColors.outline;
    final diff = DateTime.now().difference(sync.lastSyncAt!);
    if (diff.inMinutes < 60) return AppPatioColors.syncOnline;
    if (diff.inHours   < 24) return AppPatioColors.syncPending;
    return AppPatioColors.syncOffline;
  }

  @override
  Widget build(BuildContext context) {
    final isAberta = widget.caixaAberta != null;
    final saldo    = isAberta
        ? NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ')
            .format(widget.caixaAberta!.saldoCalculado)
        : 'R\$ —';

    final syncLabel = _syncLabel(widget.syncState);
    final syncColor = _syncColor(widget.syncState);
    final isSyncing = widget.syncState?.isSyncing ?? false;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 12,
      child: Stack(
        children: [
          Positioned(
            top: -20, right: -20,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppPatioColors.secondary.withValues(alpha: 0.08),
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Linha: caixa + chip status ─────────────────────────────
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: AppPatioColors.secondary, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Status do Caixa',
                    style: TextStyle(color: AppPatioColors.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isAberta ? const Color(0x4D065F46) : const Color(0x26374151),
                      border: Border.all(
                        color: isAberta ? const Color(0x664ADE80) : const Color(0x4D6B7280),
                      ),
                    ),
                    child: Text(
                      widget.caixaLoading ? '...' : (isAberta ? 'Aberto' : 'Fechado'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isAberta ? const Color(0xFF4ADE80) : AppPatioColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── Saldo ─────────────────────────────────────────────────
              const Text(
                'SALDO ATUAL',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppPatioColors.outline),
              ),
              const SizedBox(height: 2),
              widget.caixaLoading
                  ? Container(
                      width: 120, height: 28,
                      decoration: BoxDecoration(
                        color: AppPatioColors.glassFill,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    )
                  : Text(
                      saldo,
                      style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800,
                        color: AppPatioColors.secondary, letterSpacing: -0.5, height: 1.1,
                      ),
                    ),

              const SizedBox(height: 10),
              const Divider(height: 1, color: AppPatioColors.outlineVariant),
              const SizedBox(height: 10),

              // ── Linha de sync em tempo real ────────────────────────────
              Row(
                children: [
                  if (isSyncing)
                    const SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: AppPatioColors.secondary),
                    )
                  else
                    Icon(
                      widget.syncState?.hasError == true
                          ? Icons.sync_problem_rounded
                          : Icons.sync_rounded,
                      size: 13,
                      color: syncColor,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    'Sync: $syncLabel',
                    style: TextStyle(fontSize: 12, color: syncColor, fontWeight: FontWeight.w600),
                  ),
                  if (widget.syncState?.pendingCount != null &&
                      widget.syncState!.pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppPatioColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppPatioColors.warning.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '${widget.syncState!.pendingCount} pendente${widget.syncState!.pendingCount > 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppPatioColors.warning),
                      ),
                    ),
                  ],

                  if (widget.totalNoPatio > 0) ...[
                    const Spacer(),
                    const Icon(Icons.local_parking_rounded, size: 12, color: AppPatioColors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.totalNoPatio} no pátio',
                      style: const TextStyle(fontSize: 11, color: AppPatioColors.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Bento grid 2x2 ──────────────────────────────────────────────────────────

class _BentoGrid extends StatelessWidget {
  const _BentoGrid({
    required this.caixaAberta,
    required this.totalNoPatio,
    required this.onEntrada,
    required this.onSaida,
    required this.onCaixa,
    required this.onPatio,
  });

  final CaixaModel? caixaAberta;
  final int         totalNoPatio;
  final VoidCallback onEntrada;
  final VoidCallback onSaida;
  final VoidCallback onCaixa;
  final VoidCallback onPatio;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        // Entrada — gold fill (ação primária)
        _BentoButton(
          icon:  Icons.login_rounded,
          label: 'Entrada',
          style: _BentoStyle.gold,
          badge: null,
          onTap: onEntrada,
        ),
        // Saída — glass com borda dourada
        _BentoButton(
          icon:  Icons.logout_rounded,
          label: 'Saída',
          style: _BentoStyle.goldBorder,
          badge: totalNoPatio > 0 ? '$totalNoPatio' : null,
          onTap: onSaida,
        ),
        // Caixa — glass neutro
        _BentoButton(
          icon:  Icons.point_of_sale_rounded,
          label: caixaAberta != null ? 'Fechar Caixa' : 'Caixa',
          style: _BentoStyle.glass,
          badge: caixaAberta != null ? 'ABERTO' : null,
          onTap: onCaixa,
        ),
        // Ver Pátio — glass neutro
        _BentoButton(
          icon:  Icons.grid_view_rounded,
          label: 'Ver Pátio',
          style: _BentoStyle.glass,
          badge: null,
          onTap: onPatio,
        ),
      ],
    );
  }
}

enum _BentoStyle { gold, goldBorder, glass }

class _BentoButton extends StatefulWidget {
  const _BentoButton({
    required this.icon,
    required this.label,
    required this.style,
    required this.onTap,
    this.badge,
  });

  final IconData    icon;
  final String      label;
  final _BentoStyle style;
  final VoidCallback onTap;
  final String?     badge;

  @override
  State<_BentoButton> createState() => _BentoButtonState();
}

class _BentoButtonState extends State<_BentoButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isGold      = widget.style == _BentoStyle.gold;
    final isGoldBorder = widget.style == _BentoStyle.goldBorder;

    return GestureDetector(
      onTapDown: (_) { setState(() => _pressed = true); HapticFeedback.mediumImpact(); },
      onTapUp:   (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale:    _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: _BentoButtonContent(
          icon:       widget.icon,
          label:      widget.label,
          isGold:     isGold,
          isGoldBorder: isGoldBorder,
          badge:      widget.badge,
        ),
      ),
    );
  }
}

class _BentoButtonContent extends StatelessWidget {
  const _BentoButtonContent({
    required this.icon,
    required this.label,
    required this.isGold,
    required this.isGoldBorder,
    this.badge,
  });

  final IconData icon;
  final String   label;
  final bool     isGold;
  final bool     isGoldBorder;
  final String?  badge;

  @override
  Widget build(BuildContext context) {
    if (isGold) {
      return Container(
        decoration: BoxDecoration(
          color: AppPatioColors.secondary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppPatioColors.secondary.withValues(alpha: 0.2),
              blurRadius: 20, offset: const Offset(0, 6),
            ),
          ],
        ),
        child: _Content(
          icon:      icon,
          label:     label,
          iconColor: AppPatioColors.onSecondary,
          textColor: AppPatioColors.onSecondary,
          badge:     badge,
          badgeOnDark: false,
        ),
      );
    }

    if (isGoldBorder) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: AppPatioColors.glassFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPatioColors.secondary.withValues(alpha: 0.4), width: 1.5),
            ),
            child: _Content(
              icon:      icon,
              label:     label,
              iconColor: AppPatioColors.secondary,
              textColor: AppPatioColors.onSurface,
              badge:     badge,
              badgeOnDark: true,
            ),
          ),
        ),
      );
    }

    // Glass padrão
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppPatioColors.glassFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppPatioColors.glassBorder),
          ),
          child: _Content(
            icon:      icon,
            label:     label,
            iconColor: AppPatioColors.onSurfaceVariant,
            textColor: AppPatioColors.onSurfaceVariant,
            badge:     badge,
            badgeOnDark: true,
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.textColor,
    required this.badgeOnDark,
    this.badge,
  });

  final IconData icon;
  final String   label;
  final Color    iconColor;
  final Color    textColor;
  final String?  badge;
  final bool     badgeOnDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 36, color: iconColor),
              if (badge != null)
                Positioned(
                  top: -6, right: -10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeOnDark
                          ? AppPatioColors.secondary
                          : AppPatioColors.onSecondary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: badgeOnDark ? AppPatioColors.onSecondary : Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
