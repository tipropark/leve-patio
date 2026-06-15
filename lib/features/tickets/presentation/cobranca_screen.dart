import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:leve_core/leve_core.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_patio_colors.dart';
import '../../../core/utils/label_utils.dart';
import '../../caixa/presentation/providers/caixa_provider.dart';
import '../../sync/presentation/providers/sync_provider.dart';
import '../../operacao/domain/tarifa_config.dart';
import '../../operacao/presentation/providers/operacao_provider.dart';
import '../../printing/data/print_templates.dart';
import '../../printing/presentation/providers/printer_provider.dart';
import '../../tarifa/domain/fare_result.dart';
import '../../tarifa/domain/tarifa_engine.dart';
import '../domain/ticket_model.dart';
import 'providers/ticket_providers.dart';

class CobrancaScreen extends ConsumerStatefulWidget {
  const CobrancaScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<CobrancaScreen> createState() => _CobrancaScreenState();
}

class _CobrancaScreenState extends ConsumerState<CobrancaScreen> {
  // Capturado no init para que o valor não mude conforme o usuário demora.
  late final DateTime _exitTime = DateTime.now();

  String? _formaPagamento;
  bool _isIsento = false;
  String? _motivoIsencao;
  bool _confirmando = false;

  // Tabela de preço selecionada pelo operador
  TarifaConfig? _tarifaSelecionada;

  // Saída de livre passagem: gratuita, sem cobrança e sem exigir caixa aberto.
  Future<void> _confirmarLivre(TicketModel ticket) async {
    setState(() => _confirmando = true);
    try {
      await ref.read(ticketRepositoryProvider).fecharTicket(
        ticketId:       ticket.id,
        valorCalculado: 0,
        valorCobrado:   0,
        formaPagamento: 'plano',
      );
      ref.invalidate(ticketsAbertosProvider);
      Future.microtask(() => ref.read(syncNotifierProvider.notifier).trigger());

      if (mounted) {
        AppToast.success(context, 'Saída liberada — ${ticket.placa} (cliente)');
        Navigator.of(context)
          ..pop()
          ..pop();
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'Erro ao registrar saída');
    } finally {
      if (mounted) setState(() => _confirmando = false);
    }
  }

  Future<void> _confirmar(
    TicketModel ticket,
    FareResult fare,
  ) async {
    // Guard: caixa deve estar aberto antes de qualquer operação financeira
    final caixaState = ref.read(caixaSessaoNotifierProvider);
    final sessaoAberta = switch (caixaState) {
      AsyncData(:final value) when value != null && value.isAberta => value,
      _ => null,
    };
    if (sessaoAberta == null) {
      AppToast.error(context, 'Abra o caixa antes de registrar uma saída');
      return;
    }

    if (_tarifaSelecionada == null) {
      AppToast.error(context, 'Selecione a tabela de preço');
      return;
    }
    if (_formaPagamento == null) {
      AppToast.error(context, 'Selecione a forma de pagamento');
      return;
    }
    if (_isIsento && _motivoIsencao == null) {
      AppToast.error(context, 'Selecione o motivo da isenção');
      return;
    }

    setState(() => _confirmando = true);
    try {
      final valorCobrado = _isIsento ? 0.0 : fare.valor;
      await ref.read(ticketRepositoryProvider).fecharTicket(
        ticketId:       ticket.id,
        valorCalculado: fare.valor,
        valorCobrado:   valorCobrado,
        formaPagamento: _formaPagamento!,
        motivoIsencao:  _isIsento ? _motivoIsencao : null,
        tabelaPrecoId:  _tarifaSelecionada!.id,
      );

      // Atualiza a lista do pátio e dispara sync imediatamente.
      ref.invalidate(ticketsAbertosProvider);
      Future.microtask(() => ref.read(syncNotifierProvider.notifier).trigger());

      if (valorCobrado > 0) {
        await ref
            .read(caixaSessaoNotifierProvider.notifier)
            .registrarEntradaTicket(
              ticketId:       ticket.id,
              valor:          valorCobrado,
              formaPagamento: _formaPagamento!,
              placa:          ticket.placa,
            );
      }

      if (!mounted) return;

      // Show receipt sheet before popping
      final operacaoAsync = ref.read(operacaoNotifierProvider);
      final operacaoNome  = switch (operacaoAsync) {
        AsyncData(:final value) => value?.nome ?? 'Pátio',
        _ => 'Pátio',
      };

      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isDismissible: false,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _ReciboSheet(
          placa:          ticket.placa,
          tipoVeiculo:    ticket.tipoVeiculo,
          entrada:        ticket.entrada,
          saida:          _exitTime,
          valorCobrado:   valorCobrado,
          formaPagamento: _formaPagamento!,
          isIsento:       _isIsento,
          operacaoNome:   operacaoNome,
          printerAsync:   ref.read(printerNotifierProvider),
          onPrint: (bytes) =>
              ref.read(printerNotifierProvider.notifier).print(bytes),
        ),
      );

      if (mounted) {
        final valorStr = _moeda(valorCobrado);
        AppToast.success(
          context,
          _isIsento
              ? 'Saída registrada — ${ticket.placa} (isento)'
              : 'Saída registrada — ${ticket.placa} · $valorStr',
        );
        Navigator.of(context)
          ..pop()
          ..pop();
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'Erro ao registrar saída');
    } finally {
      if (mounted) setState(() => _confirmando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketAsync  = ref.watch(ticketByIdProvider(widget.ticketId));
    final operacaoAsync = ref.watch(operacaoNotifierProvider);

    return Scaffold(
      backgroundColor: AppPatioColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppPatioColors.secondary,
        title: const Text('Cobrança'),
      ),
      body: ticketAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Ticket não encontrado: $e',
            style: const TextStyle(color: AppPatioColors.danger),
          ),
        ),
        data: (ticket) {
          if (ticket == null) {
            return const Center(
              child: Text(
                'Ticket não encontrado',
                style: TextStyle(color: AppPatioColors.danger),
              ),
            );
          }

          if (ticket.status != 'aberto') {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppPatioColors.success,
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Este ticket já foi fechado',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppPatioColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ticket.placa,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: AppPatioColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.of(context)
                      ..pop()
                      ..pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPatioColors.surface,
                      foregroundColor: AppPatioColors.onSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Voltar ao pátio'),
                  ),
                ],
              ),
            );
          }

          // Livre passagem (cliente mensalista/credenciado): saída gratuita.
          if (ticket.isLivrePassagem) {
            return _SaidaLivreBody(
              ticket:      ticket,
              exitTime:    _exitTime,
              confirmando: _confirmando,
              onConfirmar: () => _confirmarLivre(ticket),
            );
          }

          return operacaoAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Erro ao carregar tarifa: $e'),
            ),
            data: (operacao) {
              if (operacao == null) {
                return const Center(child: Text('Operação não carregada'));
              }

              final tabelas = operacao.tabelasVisiveis(ticket.tipoVeiculo);
              // Se nenhuma tabela visível, cai para todas as vigentes (retrocompatibilidade)
              final opcoes = tabelas.isNotEmpty
                  ? tabelas
                  : operacao.tarifasVigentes(ticket.tipoVeiculo);

              if (opcoes.isEmpty) {
                return Center(
                  child: Text(
                    'Sem tabela de preço para "${ticket.tipoVeiculo}"',
                    style: const TextStyle(color: AppPatioColors.danger),
                  ),
                );
              }

              // Auto-seleciona se só há uma opção
              if (_tarifaSelecionada == null && opcoes.length == 1) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _tarifaSelecionada = opcoes.first);
                });
              }

              final tarifaParaCalculo = _tarifaSelecionada ?? opcoes.first;

              final fare = TarifaEngine.calcular(
                entrada: ticket.entrada,
                saida:   _exitTime,
                tarifa:  tarifaParaCalculo,
              );

              return _CobrancaBody(
                ticket:           ticket,
                fare:             fare,
                exitTime:         _exitTime,
                tabelasOpcoes:    opcoes,
                tarifaSelecionada: _tarifaSelecionada,
                formasPagamento:  operacao.formasPagamento,
                motivosIsencao:   operacao.motivosIsencao,
                formaPagamento:   _formaPagamento,
                isIsento:         _isIsento,
                motivoIsencao:    _motivoIsencao,
                confirmando:      _confirmando,
                onTabelaChanged: (v) =>
                    setState(() => _tarifaSelecionada = v),
                onFormaPagamentoChanged: (v) =>
                    setState(() => _formaPagamento = v),
                onIsentoChanged: (v) => setState(() {
                  _isIsento = v;
                  if (!v) _motivoIsencao = null;
                }),
                onMotivoChanged: (v) =>
                    setState(() => _motivoIsencao = v),
                onConfirmar: () => _confirmar(ticket, fare),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Corpo de saída livre (cliente de plano) ─────────────────────────────────

class _SaidaLivreBody extends StatelessWidget {
  const _SaidaLivreBody({
    required this.ticket,
    required this.exitTime,
    required this.confirmando,
    required this.onConfirmar,
  });

  final TicketModel ticket;
  final DateTime exitTime;
  final bool confirmando;
  final VoidCallback onConfirmar;

  @override
  Widget build(BuildContext context) {
    final duracao    = exitTime.difference(ticket.entrada);
    final h          = duracao.inHours;
    final m          = duracao.inMinutes.remainder(60);
    final duracaoStr = h > 0 ? '${h}h ${m}min' : '${m}min';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppPatioColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppPatioColors.success.withValues(alpha: 0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_rounded, color: AppPatioColors.success, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cliente de livre passagem — saída sem cobrança',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppPatioColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _SectionCard(
              children: [
                _InfoRow(
                  label: 'Placa',
                  value: ticket.placa,
                  valueStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: AppPatioColors.onSurface,
                  ),
                ),
                _InfoRow(label: 'Tipo',    value: _capitalize(ticket.tipoVeiculo)),
                _InfoRow(
                  label: 'Entrada',
                  value: DateFormat('dd/MM/yyyy HH:mm').format(ticket.entrada),
                ),
                _InfoRow(label: 'Duração', value: duracaoStr),
              ],
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppPatioColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                onPressed: confirmando ? null : onConfirmar,
                icon: confirmando
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Icon(Icons.logout_rounded),
                label: Text(confirmando ? 'Registrando…' : 'Liberar Saída'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

class _CobrancaBody extends StatelessWidget {
  const _CobrancaBody({
    required this.ticket,
    required this.fare,
    required this.exitTime,
    required this.tabelasOpcoes,
    required this.tarifaSelecionada,
    required this.formasPagamento,
    required this.motivosIsencao,
    required this.formaPagamento,
    required this.isIsento,
    required this.motivoIsencao,
    required this.confirmando,
    required this.onTabelaChanged,
    required this.onFormaPagamentoChanged,
    required this.onIsentoChanged,
    required this.onMotivoChanged,
    required this.onConfirmar,
  });

  final TicketModel ticket;
  final FareResult fare;
  final DateTime exitTime;
  final List<TarifaConfig> tabelasOpcoes;
  final TarifaConfig? tarifaSelecionada;
  final List<String> formasPagamento;
  final List<String> motivosIsencao;
  final String? formaPagamento;
  final bool isIsento;
  final String? motivoIsencao;
  final bool confirmando;
  final ValueChanged<TarifaConfig?> onTabelaChanged;
  final ValueChanged<String?> onFormaPagamentoChanged;
  final ValueChanged<bool> onIsentoChanged;
  final ValueChanged<String?> onMotivoChanged;
  final VoidCallback onConfirmar;

  @override
  Widget build(BuildContext context) {
    final duracao   = exitTime.difference(ticket.entrada);
    final h         = duracao.inHours;
    final m         = duracao.inMinutes.remainder(60);
    final duracaoStr = h > 0 ? '${h}h ${m}min' : '${m}min';
    final valorCobrado = isIsento ? 0.0 : fare.valor;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Resumo do ticket ──────────────────────────────────────────
            _SectionCard(
              children: [
                _InfoRow(
                  label: 'Placa',
                  value: ticket.placa,
                  valueStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: AppPatioColors.onSurface,
                  ),
                ),
                _InfoRow(
                  label: 'Tipo',
                  value: _capitalize(ticket.tipoVeiculo),
                ),
                _InfoRow(
                  label: 'Entrada',
                  value: DateFormat('dd/MM/yyyy HH:mm').format(ticket.entrada),
                ),
                _InfoRow(label: 'Duração', value: duracaoStr),
              ],
            ),
            const SizedBox(height: 16),

            // ── Valor calculado ───────────────────────────────────────────
            _SectionCard(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isIsento ? 'Isento' : _moeda(fare.valor),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: isIsento
                              ? AppPatioColors.textSecondary
                              : AppPatioColors.success,
                          decoration: isIsento
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    _MotivoBadge(fare.motivo),
                  ],
                ),
                if (isIsento)
                  const Text(
                    'R\$ 0,00',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppPatioColors.warning,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Tabela de preço ───────────────────────────────────────────
            if (tabelasOpcoes.length > 1) ...[
              const Text(
                'Tabela de preço',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppPatioColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tabelasOpcoes.map((t) {
                  final selected = tarifaSelecionada?.id == t.id;
                  return ChoiceChip(
                    label: Text(
                      t.nome,
                      style: TextStyle(
                        color: selected ? Colors.white : AppPatioColors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    selected: selected,
                    selectedColor: AppPatioColors.primary,
                    backgroundColor: AppPatioColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: selected
                            ? AppPatioColors.primary
                            : AppPatioColors.outline,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    onSelected: (_) => onTabelaChanged(t),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // ── Forma de pagamento ────────────────────────────────────────
            const Text(
              'Forma de pagamento',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppPatioColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: formasPagamento.map((fp) {
                final selected = formaPagamento == fp;
                return ChoiceChip(
                  label: Text(
                    LabelUtils.formaPagamento(fp),
                    style: TextStyle(
                      color: selected ? Colors.white : AppPatioColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  selected: selected,
                  selectedColor: AppPatioColors.primary,
                  backgroundColor: AppPatioColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: selected
                          ? AppPatioColors.primary
                          : AppPatioColors.outline,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  onSelected: (_) => onFormaPagamentoChanged(fp),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── Isenção ───────────────────────────────────────────────────
            if (motivosIsencao.isNotEmpty) ...[
              Row(
                children: [
                  Checkbox(
                    value: isIsento,
                    activeColor: AppPatioColors.warning,
                    onChanged: (v) => onIsentoChanged(v ?? false),
                  ),
                  const Text(
                    'Aplicar isenção',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (isIsento) ...[
                const SizedBox(height: 4),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Motivo da isenção',
                    filled: true,
                    fillColor: AppPatioColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: DropdownButton<String>(
                    value: motivoIsencao,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: motivosIsencao
                        .map(
                          (m) => DropdownMenuItem(value: m, child: Text(m)),
                        )
                        .toList(),
                    onChanged: onMotivoChanged,
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 8),
            // ── Botão confirmar ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppPatioColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: confirmando ? null : onConfirmar,
                icon: confirmando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  confirmando
                      ? 'Registrando…'
                      : 'Confirmar · ${_moeda(valorCobrado)}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppPatioColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppPatioColors.outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueStyle});
  final String label;
  final String value;
  final TextStyle? valueStyle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppPatioColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: valueStyle ??
                const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppPatioColors.onSurface,
                ),
          ),
        ),
      ],
    ),
  );
}

class _MotivoBadge extends StatelessWidget {
  const _MotivoBadge(this.motivo);
  final FareMotivo motivo;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (motivo) {
      FareMotivo.tolerancia => ('Tolerância', AppPatioColors.textSecondary),
      FareMotivo.normal     => ('Normal', AppPatioColors.primary),
      FareMotivo.tetoDiaria => ('Diária', AppPatioColors.warning),
      FareMotivo.pernoite   => ('Pernoite', const Color(0xFF6B39C5)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

String _moeda(double v) =>
    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ').format(v);

// ── Recibo Sheet ──────────────────────────────────────────────────────────

class _ReciboSheet extends StatelessWidget {
  const _ReciboSheet({
    required this.placa,
    required this.tipoVeiculo,
    required this.entrada,
    required this.saida,
    required this.valorCobrado,
    required this.formaPagamento,
    required this.isIsento,
    required this.operacaoNome,
    required this.printerAsync,
    required this.onPrint,
  });

  final String placa;
  final String tipoVeiculo;
  final DateTime entrada;
  final DateTime saida;
  final double valorCobrado;
  final String formaPagamento;
  final bool isIsento;
  final String operacaoNome;
  final AsyncValue<PrinterState> printerAsync;
  final Future<bool> Function(List<int>) onPrint;

  @override
  Widget build(BuildContext context) {
    final printer = switch (printerAsync) {
      AsyncData(:final value) => value,
      _ => const PrinterState(),
    };

    final duracao    = saida.difference(entrada);
    final h          = duracao.inHours;
    final m          = duracao.inMinutes.remainder(60);
    final duracaoStr = h > 0 ? '${h}h ${m}min' : '${m}min';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppPatioColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.check_circle_rounded,
                color: AppPatioColors.success, size: 48),
            const SizedBox(height: 8),
            Text(
              isIsento ? 'Saída registrada — Isento' : 'Pagamento registrado',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppPatioColors.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppPatioColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppPatioColors.outline),
              ),
              child: Column(
                children: [
                  _ReciboRow('Placa', placa),
                  _ReciboRow('Tipo',  _capitalize(tipoVeiculo)),
                  _ReciboRow('Tempo', duracaoStr),
                  const Divider(color: AppPatioColors.outline, height: 20),
                  _ReciboRow(
                    isIsento ? 'Isento' : 'Valor cobrado',
                    _moeda(valorCobrado),
                    bold: true,
                  ),
                  if (!isIsento)
                    _ReciboRow('Pagamento', LabelUtils.formaPagamento(formaPagamento)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (printer.isConnected) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: printer.isPrinting
                    ? const Center(child: CircularProgressIndicator())
                    : OutlinedButton.icon(
                        onPressed: () async {
                          final bytes = PrintTemplates.reciboSaida(
                            placa:          placa,
                            tipoVeiculo:    tipoVeiculo,
                            entrada:        entrada,
                            saida:          saida,
                            valorCobrado:   valorCobrado,
                            formaPagamento: formaPagamento,
                            operacaoNome:   operacaoNome,
                            isIsento:       isIsento,
                          );
                          final ok = await onPrint(bytes);
                          if (context.mounted) {
                            if (ok) {
                              AppToast.success(context, 'Recibo impresso');
                            } else {
                              AppToast.error(context, 'Falha ao imprimir');
                            }
                          }
                        },
                        icon: const Icon(Icons.print_rounded),
                        label: const Text('Imprimir Recibo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppPatioColors.primary,
                          side: const BorderSide(color: AppPatioColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppPatioColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fechar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

class _ReciboRow extends StatelessWidget {
  const _ReciboRow(this.label, this.value, {this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppPatioColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: bold ? AppPatioColors.success : AppPatioColors.onSurface,
          ),
        ),
      ],
    ),
  );
}
