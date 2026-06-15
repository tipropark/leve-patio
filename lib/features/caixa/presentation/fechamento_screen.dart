import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:leve_core/leve_core.dart';

import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_patio_colors.dart';
import '../../operacao/presentation/providers/operacao_provider.dart';
import '../../printing/data/print_templates.dart';
import '../../printing/presentation/providers/printer_provider.dart';
import '../domain/caixa_model.dart';
import 'providers/caixa_provider.dart';

class FechamentoCaixaScreen extends ConsumerStatefulWidget {
  const FechamentoCaixaScreen({super.key});

  @override
  ConsumerState<FechamentoCaixaScreen> createState() =>
      _FechamentoCaixaScreenState();
}

class _FechamentoCaixaScreenState extends ConsumerState<FechamentoCaixaScreen> {
  final _contadoCtrl = TextEditingController();
  final _obsCtrl     = TextEditingController();
  bool _confirmando = false;
  FechamentoResult? _result;
  // Saved for printing after the session is invalidated
  CaixaModel? _sessao;
  DateTime?   _fechamentoTime;

  @override
  void dispose() {
    _contadoCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmar(CaixaModel sessao) async {
    final raw      = _contadoCtrl.text.trim().replaceAll(',', '.');
    final contado  = double.tryParse(raw);
    if (contado == null || contado < 0) {
      AppToast.error(context, 'Informe o valor que você contou no caixa');
      return;
    }

    _sessao         = sessao;
    _fechamentoTime = DateTime.now();

    setState(() => _confirmando = true);
    try {
      final result = await ref.read(caixaRepositoryProvider).fecharCaixa(
        caixaSessaoId: sessao.id,
        totalContado:  contado,
        observacao:    _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
      );

      // Reseta o notifier — não há mais sessão aberta
      ref.invalidate(caixaSessaoNotifierProvider);

      setState(() {
        _result      = result;
        _confirmando = false;
      });
    } catch (e) {
      if (mounted) AppToast.error(context, 'Erro ao fechar caixa');
      setState(() => _confirmando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final caixaAsync = ref.watch(caixaSessaoNotifierProvider);

    return Scaffold(
      backgroundColor: AppPatioColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppPatioColors.secondary,
        title: const Text('Fechar Caixa'),
      ),
      body: caixaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('$e', style: const TextStyle(color: AppPatioColors.danger)),
        ),
        data: (sessao) {
          // Se já fechou (result definido), mostra o resumo
          if (_result != null) return _buildResultado(_result!);

          // Se não há sessão (já foi fechada por outro caminho ou nula)
          if (sessao == null || !sessao.isAberta) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    size: 64,
                    color: AppPatioColors.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nenhum caixa aberto',
                    style: TextStyle(
                      color: AppPatioColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => context.go(Routes.home),
                    child: const Text('Voltar para o início'),
                  ),
                ],
              ),
            );
          }

          return _buildFormulario(sessao);
        },
      ),
    );
  }

  Widget _buildFormulario(CaixaModel sessao) {
    final calculado = sessao.saldoCalculado;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Resumo calculado ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppPatioColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppPatioColors.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sistema calcula',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppPatioColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _moeda(calculado),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppPatioColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: AppPatioColors.outline),
                  const SizedBox(height: 6),
                  _SummaryRow(
                    label: 'Fundo inicial',
                    value: _moeda(sessao.fundoCaixa),
                  ),
                  _SummaryRow(
                    label: 'Total entradas',
                    value: '+${_moeda(sessao.totalEntradas)}',
                    color: AppPatioColors.success,
                  ),
                  _SummaryRow(
                    label: 'Total sangrias',
                    value: '-${_moeda(sessao.totalSangrias)}',
                    color: AppPatioColors.danger,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Total contado ─────────────────────────────────────────────────
            const Text(
              'Quanto você contou no caixa? (R\$)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppPatioColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contadoCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
              ],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppPatioColors.onSurface,
              ),
              decoration: InputDecoration(
                hintText: '0,00',
                prefixText: 'R\$ ',
                prefixStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppPatioColors.textSecondary,
                ),
                filled: true,
                fillColor: AppPatioColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
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
                    color: AppPatioColors.warning,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Observação ────────────────────────────────────────────────────
            const Text(
              'Observação (opcional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppPatioColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _obsCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Ex: Fechamento normal, sem ocorrências',
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
                    color: AppPatioColors.warning,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppPatioColors.warning,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: _confirmando ? null : () => _confirmar(sessao),
                icon: _confirmando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_rounded),
                label: const Text('Confirmar Fechamento'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _imprimir(FechamentoResult result) async {
    final sessao   = _sessao;
    final fechamento = _fechamentoTime;
    if (sessao == null || fechamento == null) return;

    final printerState = switch (ref.read(printerNotifierProvider)) {
      AsyncData(:final value) => value,
      _ => const PrinterState(),
    };

    if (!printerState.isConnected) {
      if (mounted) {
        AppToast.error(
          context,
          'Impressora não conectada. Configure em Ajustes → Impressora',
        );
      }
      return;
    }

    final operacaoAsync = ref.read(operacaoNotifierProvider);
    final operacaoNome  = switch (operacaoAsync) {
      AsyncData(:final value) => value?.nome ?? 'Pátio',
      _ => 'Pátio',
    };

    final bytes = PrintTemplates.fechamentoCaixa(
      operadorNome:   sessao.operadorNome,
      operacaoNome:   operacaoNome,
      abertura:       sessao.abertura,
      fechamento:     fechamento,
      fundoCaixa:     sessao.fundoCaixa,
      totalEntradas:  sessao.totalEntradas,
      totalSangrias:  sessao.totalSangrias,
      totalCalculado: result.totalCalculado,
      totalContado:   result.totalContado,
      divergencia:    result.divergencia,
    );

    final ok = await ref.read(printerNotifierProvider.notifier).print(bytes);
    if (mounted) {
      if (ok) {
        AppToast.success(context, 'Relatório impresso');
      } else {
        AppToast.error(context, 'Falha ao imprimir');
      }
    }
  }

  Widget _buildResultado(FechamentoResult result) {
    final divergenciaColor = result.temDivergencia
        ? (result.emFalta ? AppPatioColors.danger : AppPatioColors.warning)
        : AppPatioColors.success;

    final divergenciaLabel = result.temDivergencia
        ? (result.emFalta ? 'Falta de caixa' : 'Sobra de caixa')
        : 'Sem divergência';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Banner de resultado ──────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: divergenciaColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: divergenciaColor.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    result.temDivergencia
                        ? (result.emFalta
                            ? Icons.warning_rounded
                            : Icons.info_rounded)
                        : Icons.check_circle_rounded,
                    size: 48,
                    color: divergenciaColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    divergenciaLabel,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: divergenciaColor,
                    ),
                  ),
                  if (result.temDivergencia) ...[
                    const SizedBox(height: 4),
                    Text(
                      result.emFalta
                          ? '${_moeda(result.divergencia.abs())} a menos'
                          : '+${_moeda(result.divergencia.abs())} a mais',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: divergenciaColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Comparativo ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppPatioColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppPatioColors.outline),
              ),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Sistema calculou',
                    value: _moeda(result.totalCalculado),
                  ),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: 'Você contou',
                    value: _moeda(result.totalContado),
                  ),
                ],
              ),
            ),
            const Spacer(),

            // ── Imprimir relatório ────────────────────────────────────────────
            Consumer(
              builder: (context, ref, _) {
                final printerAsync = ref.watch(printerNotifierProvider);
                final isConnected = switch (printerAsync) {
                  AsyncData(:final value) => value.isConnected,
                  _ => false,
                };
                final isPrinting = switch (printerAsync) {
                  AsyncData(:final value) => value.isPrinting,
                  _ => false,
                };
                if (!isConnected) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: isPrinting
                        ? const Center(child: CircularProgressIndicator())
                        : OutlinedButton.icon(
                            onPressed: () => _imprimir(result),
                            icon: const Icon(Icons.print_rounded),
                            label: const Text('Imprimir Relatório'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppPatioColors.warning,
                              side: const BorderSide(
                                  color: AppPatioColors.warning),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                  ),
                );
              },
            ),

            // ── Botão voltar para home ────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppPatioColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () => context.go(Routes.home),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Ir para o início'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
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
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: color ?? AppPatioColors.onSurface,
        ),
      ),
    ],
  );
}

String _moeda(double v) =>
    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ').format(v);
