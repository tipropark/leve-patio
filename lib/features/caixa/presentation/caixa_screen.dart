import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:leve_core/leve_core.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_patio_colors.dart';
import '../../../core/utils/label_utils.dart';
import '../../../features/operacao/presentation/providers/operacao_provider.dart';
import '../domain/caixa_model.dart';
import 'providers/caixa_provider.dart';

class CaixaScreen extends ConsumerStatefulWidget {
  const CaixaScreen({super.key});

  @override
  ConsumerState<CaixaScreen> createState() => _CaixaScreenState();
}

class _CaixaScreenState extends ConsumerState<CaixaScreen> {
  final _fundoCtrl = TextEditingController();
  bool _abrindo = false;

  @override
  void dispose() {
    _fundoCtrl.dispose();
    super.dispose();
  }

  Future<void> _abrirCaixa() async {
    final raw   = _fundoCtrl.text.trim().replaceAll(',', '.');
    final fundo = double.tryParse(raw);
    if (fundo == null || fundo < 0) {
      AppToast.error(context, 'Informe um valor válido para o fundo de caixa');
      return;
    }
    setState(() => _abrindo = true);
    try {
      await ref
          .read(caixaSessaoNotifierProvider.notifier)
          .abrir(fundoCaixa: fundo);
      if (mounted) AppToast.success(context, 'Caixa aberto com ${_moeda(fundo)}');
    } catch (e) {
      if (mounted) AppToast.error(context, 'Erro ao abrir caixa');
    } finally {
      if (mounted) setState(() => _abrindo = false);
    }
  }

  void _receita(String caixaSessaoId, List<String> formasPagamento) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ReceitaSheet(
        formasPagamento: formasPagamento,
        onConfirmar: (valor, descricao, forma) async {
          Navigator.of(ctx).pop();
          try {
            await ref
                .read(caixaSessaoNotifierProvider.notifier)
                .registrarReceita(
                  valor:          valor,
                  descricao:      descricao,
                  formaPagamento: forma,
                );
            ref.invalidate(movimentosProvider(caixaSessaoId));
            if (mounted) {
              AppToast.success(context, 'Receita registrada: ${_moeda(valor)}');
            }
          } catch (e) {
            if (mounted) AppToast.error(context, 'Erro ao registrar receita');
          }
        },
      ),
    );
  }

  void _sangria(String caixaSessaoId) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SangriaSheet(
        onConfirmar: (valor, descricao) async {
          Navigator.of(ctx).pop();
          try {
            await ref
                .read(caixaSessaoNotifierProvider.notifier)
                .registrarSangria(valor: valor, descricao: descricao);
            ref.invalidate(movimentosProvider(caixaSessaoId));
            if (mounted) AppToast.success(context, 'Sangria registrada: ${_moeda(valor)}');
          } catch (e) {
            if (mounted) AppToast.error(context, 'Erro ao registrar sangria');
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final caixaAsync = ref.watch(caixaSessaoNotifierProvider);

    return caixaAsync.when(
      loading: () => _loadingScaffold(),
      error: (e, _) => _errorScaffold('$e'),
      data: (sessao) {
        if (sessao == null || !sessao.isAberta) return _buildAberturaForm();
        return _buildCaixaAberta(sessao);
      },
    );
  }

  PreferredSizeWidget _backAppBar(String title) => AppBar(
    backgroundColor: Colors.transparent,
    foregroundColor: AppPatioColors.secondary,
    leading: context.canPop()
        ? IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: AppPatioColors.secondary,
            onPressed: () => context.pop(),
          )
        : null,
    title: Text(title),
  );

  Widget _loadingScaffold() => Scaffold(
    backgroundColor: AppPatioColors.background,
    appBar: _backAppBar('Caixa'),
    body: const Center(child: CircularProgressIndicator()),
  );

  Widget _errorScaffold(String msg) => Scaffold(
    backgroundColor: AppPatioColors.background,
    appBar: _backAppBar('Caixa'),
    body: Center(
      child: Text(msg, style: const TextStyle(color: AppPatioColors.danger)),
    ),
  );

  Widget _buildAberturaForm() => Scaffold(
    backgroundColor: AppPatioColors.background,
    appBar: _backAppBar('Abrir Caixa'),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppPatioColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppPatioColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppPatioColors.warning,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Informe o valor em dinheiro que você está colocando no caixa agora.',
                      style: TextStyle(fontSize: 14, color: AppPatioColors.onSurface),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Fundo de caixa (R\$)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppPatioColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _fundoCtrl,
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
                onPressed: _abrindo ? null : _abrirCaixa,
                icon: _abrindo
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_open_rounded),
                label: const Text('Abrir Caixa'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildCaixaAberta(CaixaModel sessao) {
    final movAsync     = ref.watch(movimentosProvider(sessao.id));
    final formasPgto   = ref.watch(operacaoNotifierProvider).maybeWhen(
      data: (op) => op?.formasPagamento ?? const <String>[],
      orElse: () => const <String>[],
    );

    return Scaffold(
      backgroundColor: AppPatioColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppPatioColors.secondary,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: AppPatioColors.secondary,
                onPressed: () => context.pop(),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Caixa', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Text(
              sessao.operadorNome,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Resumo do caixa ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppPatioColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppPatioColors.outline),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Saldo atual',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppPatioColors.textSecondary,
                              ),
                            ),
                            Text(
                              _moeda(sessao.saldoCalculado),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppPatioColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppPatioColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Aberto',
                            style: TextStyle(
                              color: AppPatioColors.success,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppPatioColors.outline),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _SummaryCell(
                          label: 'Fundo',
                          value: _moeda(sessao.fundoCaixa),
                          color: AppPatioColors.textSecondary,
                        ),
                        _SummaryCell(
                          label: 'Entradas',
                          value: '+${_moeda(sessao.totalEntradas)}',
                          color: AppPatioColors.success,
                        ),
                        _SummaryCell(
                          label: 'Sangrias',
                          value: '-${_moeda(sessao.totalSangrias)}',
                          color: AppPatioColors.danger,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Movimentos ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  const Text(
                    'Movimentos',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppPatioColors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 20,
                      color: AppPatioColors.textSecondary,
                    ),
                    tooltip: 'Atualizar',
                    onPressed: () =>
                        ref.invalidate(movimentosProvider(sessao.id)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: movAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Erro: $e',
                    style: const TextStyle(color: AppPatioColors.danger),
                  ),
                ),
                data: (movimentos) {
                  if (movimentos.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nenhum movimento ainda',
                        style: TextStyle(
                          color: AppPatioColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: movimentos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final mov = movimentos[movimentos.length - 1 - i];
                      return _MovimentoTile(mov: mov);
                    },
                  );
                },
              ),
            ),

            // ── Botões ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            side: const BorderSide(color: AppPatioColors.danger),
                            foregroundColor: AppPatioColors.danger,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () => _sangria(sessao.id),
                          icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                          label: const Text('Sangria'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            side: const BorderSide(color: AppPatioColors.success),
                            foregroundColor: AppPatioColors.success,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () => _receita(sessao.id, formasPgto),
                          icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                          label: const Text('Receita'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPatioColors.warning,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () => context.push(Routes.caixaFechamento),
                      icon: const Icon(Icons.lock_rounded),
                      label: const Text('Fechar Caixa'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Movimentos tile ───────────────────────────────────────────────────────────

class _MovimentoTile extends StatelessWidget {
  const _MovimentoTile({required this.mov});

  final MovimentoModel mov;

  @override
  Widget build(BuildContext context) {
    final isSangria = mov.tipo == 'sangria';
    final isIsencao = mov.tipo == 'isencao';
    final isReceita = mov.tipo == 'receita';

    final color = isSangria
        ? AppPatioColors.danger
        : isIsencao
            ? AppPatioColors.textSecondary
            : AppPatioColors.success;

    final prefix = isSangria ? '−' : '+';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPatioColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppPatioColors.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isSangria
                  ? Icons.arrow_upward_rounded
                  : isIsencao
                      ? Icons.block_rounded
                      : isReceita
                          ? Icons.add_circle_outline_rounded
                          : Icons.arrow_downward_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mov.descricao,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppPatioColors.onSurface,
                  ),
                ),
                Text(
                  [
                    DateFormat('HH:mm').format(mov.criadoEm),
                    if (mov.formaPagamento != null)
                      LabelUtils.formaPagamento(mov.formaPagamento!),
                    if (mov.tabelaPrecoNome != null)
                      mov.tabelaPrecoNome!,
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppPatioColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$prefix${_moeda(mov.valor)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Summary cell ──────────────────────────────────────────────────────────────

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppPatioColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}

// ── Sangria bottom sheet ──────────────────────────────────────────────────────

class _SangriaSheet extends StatefulWidget {
  const _SangriaSheet({required this.onConfirmar});

  final Future<void> Function(double valor, String descricao) onConfirmar;

  @override
  State<_SangriaSheet> createState() => _SangriaSheetState();
}

class _SangriaSheetState extends State<_SangriaSheet> {
  final _valorCtrl    = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _valorCtrl.dispose();
    _descricaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final raw   = _valorCtrl.text.trim().replaceAll(',', '.');
    final valor = double.tryParse(raw);
    if (valor == null || valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um valor válido')),
      );
      return;
    }
    final descricao = _descricaoCtrl.text.trim();
    if (descricao.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o motivo da sangria')),
      );
      return;
    }
    setState(() => _loading = true);
    await widget.onConfirmar(valor, descricao);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppPatioColors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Registrar Sangria',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppPatioColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Valor retirado (R\$)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppPatioColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _valorCtrl,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
            ],
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: '0,00',
              prefixText: 'R\$ ',
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
                  color: AppPatioColors.danger,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Motivo',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppPatioColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descricaoCtrl,
            decoration: InputDecoration(
              hintText: 'Ex: Pagamento de fornecedor',
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
                  color: AppPatioColors.danger,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppPatioColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _loading ? null : _confirmar,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.remove_circle_outline_rounded),
              label: const Text('Confirmar Sangria'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Receita bottom sheet ──────────────────────────────────────────────────────

class _ReceitaSheet extends StatefulWidget {
  const _ReceitaSheet({
    required this.formasPagamento,
    required this.onConfirmar,
  });

  final List<String> formasPagamento;
  final Future<void> Function(double valor, String descricao, String forma)
      onConfirmar;

  @override
  State<_ReceitaSheet> createState() => _ReceitaSheetState();
}

class _ReceitaSheetState extends State<_ReceitaSheet> {
  final _valorCtrl    = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  String? _forma;
  bool _loading = false;

  @override
  void dispose() {
    _valorCtrl.dispose();
    _descricaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final raw   = _valorCtrl.text.trim().replaceAll(',', '.');
    final valor = double.tryParse(raw);
    if (valor == null || valor <= 0) {
      AppToast.error(context, 'Informe um valor válido');
      return;
    }
    if (_descricaoCtrl.text.trim().isEmpty) {
      AppToast.error(context, 'Informe a descrição da receita');
      return;
    }
    if (_forma == null) {
      AppToast.error(context, 'Selecione a forma de pagamento');
      return;
    }
    setState(() => _loading = true);
    await widget.onConfirmar(valor, _descricaoCtrl.text.trim(), _forma!);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppPatioColors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Lançar Receita',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppPatioColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Valor
          const Text(
            'Valor (R\$)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppPatioColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _valorCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
            ],
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: '0,00',
              prefixText: 'R\$ ',
              filled: true,
              fillColor: AppPatioColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                borderSide:
                    const BorderSide(color: AppPatioColors.success, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Descrição
          const Text(
            'Descrição',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppPatioColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descricaoCtrl,
            decoration: InputDecoration(
              hintText: 'Ex: Mensalidade cliente X',
              filled: true,
              fillColor: AppPatioColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                borderSide:
                    const BorderSide(color: AppPatioColors.success, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Forma de pagamento
          if (widget.formasPagamento.isNotEmpty) ...[
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
              children: widget.formasPagamento.map((fp) {
                final sel = _forma == fp;
                return ChoiceChip(
                  label: Text(
                    LabelUtils.formaPagamento(fp),
                    style: TextStyle(
                      color: sel ? Colors.white : AppPatioColors.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  selected: sel,
                  selectedColor: AppPatioColors.success,
                  backgroundColor: AppPatioColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: sel ? AppPatioColors.success : AppPatioColors.outline,
                    ),
                  ),
                  onSelected: (_) => setState(() => _forma = fp),
                );
              }).toList(),
            ),
          ] else ...[
            // Sem formas configuradas: input livre
            const Text(
              'Forma de pagamento',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppPatioColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _FormaLivreField(
              onChanged: (v) => setState(() => _forma = v.isEmpty ? null : v),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppPatioColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _loading ? null : _confirmar,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Confirmar Receita'),
            ),
          ),
        ],
      ),
    );
  }

}

class _FormaLivreField extends StatelessWidget {
  const _FormaLivreField({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: 'Ex: Dinheiro, Pix, Cartão…',
      filled: true,
      fillColor: AppPatioColors.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        borderSide:
            const BorderSide(color: AppPatioColors.success, width: 2),
      ),
    ),
  );
}

String _moeda(double v) =>
    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ').format(v);
