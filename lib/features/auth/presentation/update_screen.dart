import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/app_patio_colors.dart';
import 'providers/auth_provider.dart';

class UpdateScreen extends ConsumerWidget {
  const UpdateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    final (minVersion, forceUpdate, user) = switch (authState) {
      AuthNeedsUpdate(:final user, :final minVersion, :final forceUpdate) =>
        (minVersion, forceUpdate, user),
      _ => ('?', true, null),
    };

    return Scaffold(
      backgroundColor: AppPatioColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.system_update_alt_rounded,
                size: 80,
                color: AppPatioColors.warning,
              ),
              const SizedBox(height: 24),
              const Text(
                'Atualização necessária',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppPatioColors.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                forceUpdate
                    ? 'Esta versão do app não é mais suportada. Por favor, instale a versão mais recente para continuar.'
                    : 'Uma nova versão está disponível. Recomendamos atualizar para ter acesso a todas as funcionalidades.',
                style: const TextStyle(
                  fontSize: 15,
                  color: AppPatioColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // ── Version comparison card ──────────────────────────────────
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
                    const _VersionRow(
                      label: 'Versão instalada',
                      value: 'v${Env.appVersion}',
                      color: AppPatioColors.danger,
                    ),
                    const SizedBox(height: 8),
                    _VersionRow(
                      label: 'Versão mínima',
                      value: 'v$minVersion',
                      color: AppPatioColors.success,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Contact IT ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppPatioColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppPatioColors.primary.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.phone_rounded,
                        color: AppPatioColors.primary, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Entre em contato com o TI da Leve para receber o novo arquivo de instalação.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppPatioColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (!forceUpdate && user != null) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => ref
                        .read(authControllerProvider.notifier)
                        .continuarOffline(user),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppPatioColors.textSecondary,
                      side: const BorderSide(color: AppPatioColors.outline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Continuar mesmo assim'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppPatioColors.textSecondary,
          ),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    ],
  );
}
