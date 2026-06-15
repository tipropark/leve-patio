import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:leve_core/leve_core.dart';

import '../../../core/config/env.dart';
import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_patio_colors.dart';
import '../../../core/widgets/patio_bottom_nav.dart';
import '../../auth/domain/patio_user.dart';
import '../../auth/presentation/providers/auth_provider.dart';

class AjustesScreen extends ConsumerWidget {
  const AjustesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = switch (authState) {
      AuthLoggedIn(:final user) => user,
      _ => null,
    };

    return Scaffold(
      backgroundColor: AppPatioColors.background,
      extendBody: true,
      bottomNavigationBar: const PatioBottomNav(currentIndex: 3),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppPatioColors.secondary,
        title: const Text('Ajustes'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (user != null) _UserCard(user: user),
            if (user != null) const SizedBox(height: 20),

            // ── Menu items ────────────────────────────────────────────────
            const _SectionHeader('Ferramentas'),
            const SizedBox(height: 8),
            _MenuItem(
              icon: Icons.print_rounded,
              label: 'Impressora Bluetooth',
              subtitle: 'Conectar e configurar impressora',
              onTap: () => context.push(Routes.impressora),
            ),
            const SizedBox(height: 8),
            _MenuItem(
              icon: Icons.sync_rounded,
              label: 'Sincronização',
              subtitle: 'Ver status e itens pendentes',
              onTap: () => context.push(Routes.sync),
            ),
            const SizedBox(height: 20),

            // ── ID do dispositivo ─────────────────────────────────────────
            const _SectionHeader('Dispositivo'),
            const SizedBox(height: 8),
            const _DeviceIdCard(),
            const SizedBox(height: 20),

            // ── App info ─────────────────────────────────────────────────
            const _SectionHeader('Sobre'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppPatioColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppPatioColors.outline),
              ),
              child: Column(
                children: [
                  const _InfoRow('App', 'Leve Pátio'),
                  const SizedBox(height: 6),
                  _InfoRow('Versão', Env.versionDisplay),
                  if (Env.buildNumber != '0') ...[
                    const SizedBox(height: 6),
                    const _InfoRow('Build', '#${Env.buildNumber}'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Logout ────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPatioColors.danger,
                  side: const BorderSide(color: AppPatioColors.danger),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () => _confirmarLogout(context, ref),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sair do aplicativo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair do aplicativo?'),
        content: const Text(
          'Você precisará fazer login novamente. Dados sincronizados serão mantidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppPatioColors.danger,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});
  final PatioUser user;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppPatioColors.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
          color: AppPatioColors.primary.withValues(alpha: 0.25)),
    ),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppPatioColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              user.nome.isNotEmpty
                  ? user.nome[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.nome,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppPatioColors.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Matrícula: ${user.matricula}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppPatioColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Text(
                'Operador de Pátio',
                style: TextStyle(
                  fontSize: 12,
                  color: AppPatioColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title.toUpperCase(),
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
      color: AppPatioColors.textSecondary,
    ),
  );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppPatioColors.surface,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppPatioColors.outline),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppPatioColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppPatioColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppPatioColors.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppPatioColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppPatioColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

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
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppPatioColors.onSurface,
        ),
      ),
    ],
  );
}

// ── Card: ID do dispositivo ───────────────────────────────────────────────

class _DeviceIdCard extends ConsumerStatefulWidget {
  const _DeviceIdCard();

  @override
  ConsumerState<_DeviceIdCard> createState() => _DeviceIdCardState();
}

class _DeviceIdCardState extends ConsumerState<_DeviceIdCard> {
  String? _deviceUuid;
  bool _copiado = false;

  static String _shortCode(String uuid) =>
      uuid.replaceAll('-', '').substring(0, 8).toUpperCase();

  @override
  void initState() {
    super.initState();
    ref.read(tokenStorageProvider).getOrCreateDeviceUuid().then((id) {
      if (mounted) setState(() => _deviceUuid = id);
    });
  }

  Future<void> _copiar() async {
    if (_deviceUuid == null) return;
    await Clipboard.setData(ClipboardData(text: _shortCode(_deviceUuid!)));
    if (!mounted) return;
    setState(() => _copiado = true);
    AppToast.success(context, 'Código copiado!');
    await Future<void>.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _copiado = false);
  }

  @override
  Widget build(BuildContext context) {
    final code = _deviceUuid != null ? _shortCode(_deviceUuid!) : null;

    return Container(
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
            'Código do dispositivo',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppPatioColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Informe este código ao administrador para vincular o tablet a um pátio.',
            style: TextStyle(
              fontSize: 12,
              color: AppPatioColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: code == null
                    ? const SizedBox(
                        height: 14,
                        child: LinearProgressIndicator(),
                      )
                    : Text(
                        code,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppPatioColors.onSurface,
                          letterSpacing: 3,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _copiar,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _copiado
                        ? AppPatioColors.success.withValues(alpha: 0.12)
                        : AppPatioColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _copiado
                          ? AppPatioColors.success
                          : AppPatioColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _copiado ? Icons.check_rounded : Icons.copy_rounded,
                        size: 14,
                        color: _copiado
                            ? AppPatioColors.success
                            : AppPatioColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _copiado ? 'Copiado' : 'Copiar',
                        style: TextStyle(
                          fontSize: 11,
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
        ],
      ),
    );
  }
}

