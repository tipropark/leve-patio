import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leve_core/leve_core.dart';

import '../../../core/theme/app_patio_colors.dart';
import '../../operacao/domain/operacao_resumo.dart';
import '../../auth/domain/patio_user.dart';
import 'providers/auth_provider.dart';

/// Exibida quando o app está instalado mas o dispositivo ainda não foi
/// vinculado a nenhum pátio no ERP (admin precisa fazer isso).
class DispositivoNaoVinculadoScreen extends ConsumerStatefulWidget {
  const DispositivoNaoVinculadoScreen({
    super.key,
    required this.user,
    required this.deviceUuid,
    required this.operacoes,
  });

  final PatioUser user;
  final String deviceUuid;
  final List<OperacaoResumo> operacoes;

  @override
  ConsumerState<DispositivoNaoVinculadoScreen> createState() =>
      _DispositivoNaoVinculadoScreenState();
}

class _DispositivoNaoVinculadoScreenState
    extends ConsumerState<DispositivoNaoVinculadoScreen> {
  bool _verificando = false;
  bool _copiado     = false;

  String get _shortCode =>
      widget.deviceUuid.replaceAll('-', '').substring(0, 8).toUpperCase();

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: _shortCode));
    if (!mounted) return;
    setState(() => _copiado = true);
    AppToast.success(context, 'Código copiado!');
    await Future<void>.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _copiado = false);
  }

  Future<void> _verificar() async {
    setState(() => _verificando = true);
    try {
      await ref.read(authControllerProvider.notifier).verificarVinculo();
      // O router reage ao novo estado — não navega explicitamente
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  void _selecionarManualmente() {
    ref.read(authControllerProvider.notifier).selecionarOperacaoManual(
      widget.user,
      widget.operacoes,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPatioColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Ícone
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppPatioColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppPatioColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.link_off_rounded,
                    size: 38,
                    color: AppPatioColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Título
              const Text(
                'Dispositivo não vinculado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppPatioColors.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),

              // Descrição
              const Text(
                'Este dispositivo precisa ser vinculado a um pátio pelo administrador do sistema antes de ser usado.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppPatioColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Card com ID do dispositivo
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppPatioColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppPatioColors.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CÓDIGO DO DISPOSITIVO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: AppPatioColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _shortCode,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppPatioColors.onSurface,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _copiar,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _copiado
                                  ? AppPatioColors.success.withValues(alpha: 0.15)
                                  : AppPatioColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _copiado
                                    ? AppPatioColors.success
                                    : AppPatioColors.primary.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _copiado
                                      ? Icons.check_rounded
                                      : Icons.copy_rounded,
                                  size: 15,
                                  color: _copiado
                                      ? AppPatioColors.success
                                      : AppPatioColors.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _copiado ? 'Copiado' : 'Copiar',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _copiado
                                        ? AppPatioColors.success
                                        : AppPatioColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppPatioColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 15,
                            color: AppPatioColors.primary,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Envie este ID para o administrador. Ele vinculará o dispositivo em:\nE-Park → Configurações → Dispositivos Vinculados',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppPatioColors.primary,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Botão principal: verificar novamente
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPatioColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: _verificando ? null : _verificar,
                  icon: _verificando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 20),
                  label: Text(_verificando ? 'Verificando…' : 'Verificar vínculo'),
                ),
              ),
              const SizedBox(height: 12),

              // Botão secundário: selecionar pátio manualmente
              if (widget.operacoes.isNotEmpty)
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppPatioColors.textSecondary,
                      side: const BorderSide(color: AppPatioColors.outline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: _selecionarManualmente,
                    icon: const Icon(Icons.touch_app_rounded, size: 18),
                    label: const Text('Selecionar pátio manualmente'),
                  ),
                ),

              const SizedBox(height: 16),

              // Logout
              Center(
                child: TextButton(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).logout(),
                  child: const Text(
                    'Sair',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppPatioColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
