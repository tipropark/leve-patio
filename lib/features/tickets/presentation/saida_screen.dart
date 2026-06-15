import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:leve_core/leve_core.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_patio_colors.dart';
import '../../caixa/presentation/providers/caixa_provider.dart';
import '../domain/ticket_model.dart';
import 'providers/ticket_providers.dart';

class SaidaScreen extends ConsumerStatefulWidget {
  const SaidaScreen({super.key});

  @override
  ConsumerState<SaidaScreen> createState() => _SaidaScreenState();
}

class _SaidaScreenState extends ConsumerState<SaidaScreen> {
  final _searchCtrl = TextEditingController();
  String _filtro = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanQr() async {
    final ticketId = await context.push<String>(Routes.qrScanner);
    if (ticketId != null && mounted) {
      context.push(Routes.saidaDetalhe(ticketId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(ticketsAbertosProvider);
    final caixaAberta  = ref.watch(caixaSessaoNotifierProvider).maybeWhen(
      data: (v) => (v != null && v.isAberta) ? v : null,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: AppPatioColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppPatioColors.secondary,
        title: const Text('Saída de Veículo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Ler QR Code do ticket',
            onPressed: _scanQr,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (caixaAberta == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppPatioColors.warning.withValues(alpha: 0.15),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppPatioColors.warning, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Caixa fechado — abra o caixa para registrar saídas',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppPatioColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(7),
                  _UpperCaseFormatter(),
                ],
                decoration: InputDecoration(
                  hintText: 'Buscar por placa…',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppPatioColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppPatioColors.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppPatioColors.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppPatioColors.primary,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (v) => setState(() => _filtro = v.toUpperCase()),
              ),
            ),
            Expanded(
              child: ticketsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Erro ao carregar tickets: $e',
                    style: const TextStyle(color: AppPatioColors.danger),
                  ),
                ),
                data: (tickets) {
                  final filtrados = _filtro.isEmpty
                      ? tickets
                      : tickets
                          .where((t) => t.placa.contains(_filtro))
                          .toList();

                  if (filtrados.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_parking_rounded,
                            size: 64,
                            color: AppPatioColors.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _filtro.isEmpty
                                ? 'Nenhum veículo no pátio'
                                : 'Nenhuma placa encontrada para "$_filtro"',
                            style: const TextStyle(
                              color: AppPatioColors.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(ticketsAbertosProvider.future),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: filtrados.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _TicketCard(
                        ticket: filtrados[i],
                        onTap: () {
                          if (caixaAberta == null) {
                            AppToast.error(context, 'Abra o caixa antes de registrar saídas');
                            return;
                          }
                          context.push(Routes.saidaDetalhe(filtrados[i].id));
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final TicketModel ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duracao  = ticket.tempoPermanencia;
    final h        = duracao.inHours;
    final m        = duracao.inMinutes.remainder(60);
    final duracaoStr = h > 0 ? '${h}h ${m}min' : '${m}min';
    final entradaStr = DateFormat('HH:mm').format(ticket.entrada);

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
            border: Border.all(color: AppPatioColors.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppPatioColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.directions_car_rounded,
                  color: AppPatioColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.placa,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: AppPatioColors.onSurface,
                      ),
                    ),
                    Text(
                      '${_capitalize(ticket.tipoVeiculo)} • Entrada $entradaStr',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppPatioColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    duracaoStr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppPatioColors.onSurface,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppPatioColors.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
