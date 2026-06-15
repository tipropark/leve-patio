import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leve_core/leve_core.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_patio_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../caixa/presentation/providers/caixa_provider.dart';
import '../../operacao/domain/operacao_model.dart';
import '../../operacao/domain/tarifa_config.dart';
import '../../operacao/presentation/providers/operacao_provider.dart';
import '../../sync/presentation/providers/sync_provider.dart';
import '../../printing/data/print_templates.dart';
import '../../printing/presentation/providers/printer_provider.dart';
import '../domain/reconhecimento_cliente.dart';
import 'providers/ticket_providers.dart';

class EntradaScreen extends ConsumerStatefulWidget {
  const EntradaScreen({super.key});

  @override
  ConsumerState<EntradaScreen> createState() => _EntradaScreenState();
}

class _EntradaScreenState extends ConsumerState<EntradaScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _placaCtrl = TextEditingController();

  String?  _tipoVeiculo;
  String?  _tarifaId;       // opcional — pode ser definida na entrada ou na saída
  bool     _loading = false;
  ReconhecimentoCliente? _reconhecimento;

  @override
  void dispose() {
    _placaCtrl.dispose();
    super.dispose();
  }

  // Limpa a tarifa selecionada ao mudar o tipo de veículo
  void _selecionarTipo(String tipo) {
    setState(() {
      _tipoVeiculo = tipo;
      _tarifaId    = null;
    });
  }

  // Reconhece a placa contra o cache local de clientes (livre passagem).
  Future<void> _checarPlaca(String placa) async {
    final norm = placa.trim().toUpperCase();
    if (norm.length < 7) {
      if (_reconhecimento != null) setState(() => _reconhecimento = null);
      return;
    }
    final operacaoId = ref.read(operacaoNotifierProvider).value?.id;
    if (operacaoId == null) return;

    final r = await ref
        .read(ticketRepositoryProvider)
        .reconhecerPlaca(operacaoId, norm);
    if (mounted) setState(() => _reconhecimento = r);
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tipoVeiculo == null) {
      AppToast.error(context, 'Selecione o tipo de veículo');
      return;
    }

    setState(() => _loading = true);
    try {
      final storage    = ref.read(tokenStorageProvider);
      final operacaoId = await storage.readOperacaoId();
      final user       = await storage.readUser();

      if (operacaoId == null || user == null) {
        if (mounted) AppToast.error(context, 'Sessão inválida. Faça login novamente.');
        return;
      }

      final caixaState    = ref.read(caixaSessaoNotifierProvider);
      final caixaSessaoId = switch (caixaState) {
        AsyncData(:final value) => value?.id,
        _ => null,
      };

      final placa = _placaCtrl.text.trim().toUpperCase();
      final tipo  = _tipoVeiculo!;
      final agora = DateTime.now();

      // Livre passagem só quando o reconhecimento confirma a elegibilidade.
      final livre = _reconhecimento?.liberaPassagem ?? false;

      final ticketId = await ref.read(ticketRepositoryProvider).registrarEntrada(
        placa:         placa,
        tipoVeiculo:   tipo,
        operacaoId:    operacaoId,
        operadorId:    user.id,
        caixaSessaoId: caixaSessaoId,
        tarifaId:      _tarifaId,
        clienteId:     livre ? _reconhecimento!.clienteId : null,
        planoId:       livre ? _reconhecimento!.planoId : null,
        origem:        livre ? 'plano' : 'avulso',
      );

      // Atualiza as listas (Home/Pátio/Saída) imediatamente — leem do DB local,
      // então o veículo aparece na hora, inclusive offline.
      ref.invalidate(ticketsAbertosProvider);

      if (!mounted) return;

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
        builder: (_) => _EntradaQrSheet(
          ticketId:     ticketId,
          placa:        placa,
          tipoVeiculo:  tipo,
          entrada:      agora,
          operacaoNome: operacaoNome,
          printerAsync: ref.read(printerNotifierProvider),
          onPrint: (bytes) =>
              ref.read(printerNotifierProvider.notifier).print(bytes),
        ),
      );

      Future.microtask(() => ref.read(syncNotifierProvider.notifier).trigger());

      if (mounted) {
        AppToast.success(context, 'Entrada registrada — $placa');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'Erro ao registrar entrada');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final operacaoAsync = ref.watch(operacaoNotifierProvider);

    return Scaffold(
      backgroundColor: AppPatioColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppPatioColors.secondary,
        title: const Text('Registrar Entrada'),
      ),
      body: operacaoAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppPatioColors.secondary),
        ),
        error: (e, _) => _BootstrapError(
          onRetry: () => ref.read(operacaoNotifierProvider.notifier).bootstrap(),
        ),
        data: (operacao) {
          if (operacao == null) {
            return _BootstrapError(
              mensagem: 'Dados do pátio não encontrados.\nVerifique a conexão.',
              onRetry: () => ref.read(operacaoNotifierProvider.notifier).bootstrap(),
            );
          }
          return _EntradaForm(
            operacao:       operacao,
            tipoVeiculo:    _tipoVeiculo,
            tarifaId:       _tarifaId,
            loading:        _loading,
            placaCtrl:      _placaCtrl,
            formKey:        _formKey,
            reconhecimento: _reconhecimento,
            onPlacaChanged: _checarPlaca,
            onTipoSelecionado: _selecionarTipo,
            onTarifaSelecionada: (id) => setState(() => _tarifaId = id),
            onRegistrar:  _registrar,
          );
        },
      ),
    );
  }
}

// ── Formulário principal ────────────────────────────────────────────────────

class _EntradaForm extends StatelessWidget {
  const _EntradaForm({
    required this.operacao,
    required this.tipoVeiculo,
    required this.tarifaId,
    required this.loading,
    required this.placaCtrl,
    required this.formKey,
    required this.reconhecimento,
    required this.onPlacaChanged,
    required this.onTipoSelecionado,
    required this.onTarifaSelecionada,
    required this.onRegistrar,
  });

  final OperacaoModel operacao;
  final String?       tipoVeiculo;
  final String?       tarifaId;
  final bool          loading;
  final TextEditingController placaCtrl;
  final GlobalKey<FormState>  formKey;
  final ReconhecimentoCliente? reconhecimento;
  final void Function(String) onPlacaChanged;
  final void Function(String) onTipoSelecionado;
  final void Function(String?) onTarifaSelecionada;
  final VoidCallback onRegistrar;

  @override
  Widget build(BuildContext context) {
    final tabelasDisponiveis = tipoVeiculo != null
        ? operacao.tabelasVisiveis(tipoVeiculo!)
        : <TarifaConfig>[];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Placa ────────────────────────────────────────────────────
              const _Label('Placa do veículo'),
              const SizedBox(height: 8),
              TextFormField(
                controller: placaCtrl,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(7),
                  _UpperCaseFormatter(),
                ],
                decoration: const InputDecoration(
                  hintText: 'Ex: ABC1234 ou ABC1D23',
                  prefixIcon: Icon(Icons.directions_car_rounded),
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: AppPatioColors.onSurface,
                ),
                onChanged: onPlacaChanged,
                validator: (v) {
                  if (v == null || v.trim().length < 7) {
                    return 'Placa deve ter 7 caracteres';
                  }
                  return null;
                },
              ),

              // ── Reconhecimento de cliente (livre passagem) ───────────────
              if (reconhecimento != null) ...[
                const SizedBox(height: 14),
                _ReconhecimentoBanner(reconhecimento: reconhecimento!),
              ],

              const SizedBox(height: 28),

              // ── Tipo de veículo ──────────────────────────────────────────
              const _Label('Tipo de veículo'),
              const SizedBox(height: 10),
              if (operacao.tiposVeiculo.isEmpty)
                const GlassCard(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppPatioColors.warning, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Nenhum tipo de veículo configurado neste pátio.',
                          style: TextStyle(color: AppPatioColors.onSurfaceVariant, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: operacao.tiposVeiculo.map((tipo) {
                    final selected = tipoVeiculo == tipo;
                    return _TipoChip(
                      tipo:     tipo,
                      selected: selected,
                      onTap:    () => onTipoSelecionado(tipo),
                    );
                  }).toList(),
                ),

              // ── Tabela de preço (opcional) ────────────────────────────────
              if (tipoVeiculo != null) ...[
                const SizedBox(height: 28),
                Row(
                  children: [
                    const _Label('Tabela de preço'),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: AppPatioColors.glassFill,
                        border: Border.all(color: AppPatioColors.outlineVariant),
                      ),
                      child: const Text(
                        'opcional',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppPatioColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pode ser definida agora ou no momento da saída.',
                  style: TextStyle(fontSize: 12, color: AppPatioColors.onSurfaceVariant),
                ),
                const SizedBox(height: 10),

                if (tabelasDisponiveis.isEmpty)
                  const Text(
                    'Nenhuma tabela de preço disponível para este tipo.',
                    style: TextStyle(fontSize: 12, color: AppPatioColors.outline),
                  )
                else
                  _TabelaPrecoSelector(
                    tarifas:          tabelasDisponiveis,
                    tarifaIdSelecionada: tarifaId,
                    onSelecionada:    onTarifaSelecionada,
                  ),
              ],

              const SizedBox(height: 40),

              // ── Botão registrar ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPatioColors.secondary,
                    foregroundColor: AppPatioColors.onSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  onPressed: loading ? null : () {
                    HapticFeedback.mediumImpact();
                    onRegistrar();
                  },
                  icon: loading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppPatioColors.onSecondary,
                          ),
                        )
                      : const Icon(Icons.login_rounded),
                  label: const Text('Registrar Entrada'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chip de tipo de veículo ─────────────────────────────────────────────────

class _TipoChip extends StatelessWidget {
  const _TipoChip({
    required this.tipo,
    required this.selected,
    required this.onTap,
  });

  final String tipo;
  final bool   selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppPatioColors.secondary
              : AppPatioColors.glassFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppPatioColors.secondary
                : AppPatioColors.glassBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          _capitalize(tipo),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: selected
                ? AppPatioColors.onSecondary
                : AppPatioColors.onSurface,
          ),
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

// ── Seletor de tabela de preço ───────────────────────────────────────────────

class _TabelaPrecoSelector extends StatelessWidget {
  const _TabelaPrecoSelector({
    required this.tarifas,
    required this.tarifaIdSelecionada,
    required this.onSelecionada,
  });

  final List<TarifaConfig> tarifas;
  final String?            tarifaIdSelecionada;
  final void Function(String?) onSelecionada;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: tarifas.map((t) {
        final selected = tarifaIdSelecionada == t.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              // Toggle — toca de novo para desmarcar
              onSelecionada(selected ? null : t.id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: selected
                    ? AppPatioColors.secondary.withValues(alpha: 0.12)
                    : AppPatioColors.glassFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? AppPatioColors.secondary.withValues(alpha: 0.7)
                      : AppPatioColors.glassBorder,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // Checkbox visual
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? AppPatioColors.secondary
                            : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? AppPatioColors.secondary
                              : AppPatioColors.outline,
                          width: 1.5,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded, size: 12, color: AppPatioColors.onSecondary)
                          : null,
                    ),
                    const SizedBox(width: 12),

                    // Dados da tarifa
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.nome,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? AppPatioColors.secondary
                                  : AppPatioColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'R\$ ${t.fracaoInicialValor.toStringAsFixed(2)} / ${t.fracaoInicialMinutos}min'
                            '  •  R\$ ${t.fracaoAdicionalValor.toStringAsFixed(2)} adicional',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppPatioColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Banner de reconhecimento de cliente ─────────────────────────────────────

class _ReconhecimentoBanner extends StatelessWidget {
  const _ReconhecimentoBanner({required this.reconhecimento});

  final ReconhecimentoCliente reconhecimento;

  @override
  Widget build(BuildContext context) {
    final livre = reconhecimento.liberaPassagem;
    final cor = switch (reconhecimento.status) {
      StatusReconhecimento.livrePassagem  => AppPatioColors.success,
      StatusReconhecimento.bloqueado      => AppPatioColors.danger,
      StatusReconhecimento.vencido        => AppPatioColors.warning,
      StatusReconhecimento.vagasEsgotadas => AppPatioColors.warning,
    };
    final icone = livre ? Icons.verified_rounded : Icons.warning_amber_rounded;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icone, color: cor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reconhecimento.nome,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppPatioColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${reconhecimento.planoNome ?? 'Sem plano'} · ${reconhecimento.mensagem}',
                  style: TextStyle(fontSize: 12, color: cor, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Estado de erro de bootstrap ─────────────────────────────────────────────

class _BootstrapError extends StatelessWidget {
  const _BootstrapError({
    this.mensagem = 'Não foi possível carregar os dados do pátio.\nVerifique a conexão.',
    required this.onRetry,
  });

  final String mensagem;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: AppPatioColors.warning),
          const SizedBox(height: 16),
          Text(
            mensagem,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppPatioColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}

// ── Label ───────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppPatioColors.onSurfaceVariant,
    ),
  );
}

// ── Formatter de placa ───────────────────────────────────────────────────────

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

// ── QR Sheet após registro ───────────────────────────────────────────────────

class _EntradaQrSheet extends StatelessWidget {
  const _EntradaQrSheet({
    required this.ticketId,
    required this.placa,
    required this.tipoVeiculo,
    required this.entrada,
    required this.operacaoNome,
    required this.printerAsync,
    required this.onPrint,
  });

  final String ticketId;
  final String placa;
  final String tipoVeiculo;
  final DateTime entrada;
  final String operacaoNome;
  final AsyncValue<PrinterState> printerAsync;
  final Future<bool> Function(List<int>) onPrint;

  @override
  Widget build(BuildContext context) {
    final printer = switch (printerAsync) {
      AsyncData(:final value) => value,
      _ => const PrinterState(),
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppPatioColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppPatioColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: AppPatioColors.success, size: 28),
            ),
            const SizedBox(height: 12),
            const Text(
              'Entrada registrada!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppPatioColors.onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              placa,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                color: AppPatioColors.secondary,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppPatioColors.outlineVariant),
              ),
              child: QrImageView(data: ticketId, version: QrVersions.auto, size: 200),
            ),
            const SizedBox(height: 8),
            Text(
              'ID: ${ticketId.substring(0, 8).toUpperCase()}',
              style: const TextStyle(fontSize: 12, color: AppPatioColors.onSurfaceVariant, letterSpacing: 1),
            ),
            const SizedBox(height: 24),
            if (printer.isConnected) ...[
              SizedBox(
                width: double.infinity, height: 52,
                child: printer.isPrinting
                    ? const Center(child: CircularProgressIndicator(color: AppPatioColors.secondary))
                    : OutlinedButton.icon(
                        onPressed: () async {
                          final bytes = PrintTemplates.ticketEntrada(
                            ticketId:     ticketId,
                            placa:        placa,
                            tipoVeiculo:  tipoVeiculo,
                            entrada:      entrada,
                            operacaoNome: operacaoNome,
                          );
                          final ok = await onPrint(bytes);
                          if (context.mounted) {
                            if (ok) { AppToast.success(context, 'Ticket impresso'); }
                            else   { AppToast.error(context, 'Falha ao imprimir'); }
                          }
                        },
                        icon: const Icon(Icons.print_rounded),
                        label: const Text('Imprimir Ticket'),
                      ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity, height: 56,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fechar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
