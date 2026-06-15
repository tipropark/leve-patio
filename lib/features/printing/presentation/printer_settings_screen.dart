import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leve_core/leve_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../core/theme/app_patio_colors.dart';
import 'providers/printer_provider.dart';

// ── Permission state machine ──────────────────────────────────────────────

enum _PermState { checking, granted, denied, permanentlyDenied }

// ── Screen ────────────────────────────────────────────────────────────────

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() =>
      _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen>
    with WidgetsBindingObserver {
  _PermState _permState = _PermState.checking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPerms();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check when the user returns from the system settings screen.
    if (state == AppLifecycleState.resumed &&
        _permState == _PermState.permanentlyDenied) {
      _checkPerms();
    }
  }

  // ── Permission helpers ────────────────────────────────────────────────

  Future<void> _checkPerms() async {
    setState(() => _permState = _PermState.checking);

    final scan    = await Permission.bluetoothScan.status;
    final connect = await Permission.bluetoothConnect.status;

    if (!mounted) return;

    if (scan.isPermanentlyDenied || connect.isPermanentlyDenied) {
      setState(() => _permState = _PermState.permanentlyDenied);
    } else if (scan.isGranted && connect.isGranted) {
      setState(() => _permState = _PermState.granted);
      // Auto-scan on first grant so the list appears immediately.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(printerNotifierProvider.notifier).scan();
      });
    } else {
      setState(() => _permState = _PermState.denied);
    }
  }

  Future<void> _requestPerms() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    if (!mounted) return;

    final anyPerm = statuses.values.any((s) => s.isPermanentlyDenied);
    final allGrant = statuses.values.every((s) => s.isGranted);

    if (allGrant) {
      setState(() => _permState = _PermState.granted);
      ref.read(printerNotifierProvider.notifier).scan();
    } else if (anyPerm) {
      setState(() => _permState = _PermState.permanentlyDenied);
    } else {
      setState(() => _permState = _PermState.denied);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final printerAsync = ref.watch(printerNotifierProvider);

    return Scaffold(
      backgroundColor: AppPatioColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppPatioColors.secondary,
        title: const Text('Impressora Bluetooth'),
      ),
      body: SafeArea(
        child: switch (_permState) {
          _PermState.checking => const Center(
              child: CircularProgressIndicator(),
            ),
          _PermState.denied => _PermissionCard(
              icon: Icons.bluetooth_disabled_rounded,
              title: 'Permissão de Bluetooth necessária',
              message:
                  'Para conectar à impressora, permita o acesso ao Bluetooth deste dispositivo.',
              buttonLabel: 'Conceder permissão',
              onTap: _requestPerms,
            ),
          _PermState.permanentlyDenied => _PermissionCard(
              icon: Icons.block_rounded,
              title: 'Permissão negada permanentemente',
              message:
                  'Abra as configurações do Android e conceda a permissão de Bluetooth manualmente para este app.',
              buttonLabel: 'Abrir configurações',
              onTap: () async {
                await openAppSettings();
              },
            ),
          _PermState.granted => printerAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  '$e',
                  style: const TextStyle(color: AppPatioColors.danger),
                ),
              ),
              data: (printer) => _DeviceListView(
                printer: printer,
                onScan: () =>
                    ref.read(printerNotifierProvider.notifier).scan(),
                onConnect: (d) =>
                    ref.read(printerNotifierProvider.notifier).connect(d),
                onDisconnect: () {
                  ref.read(printerNotifierProvider.notifier).disconnect();
                  AppToast.info(context, 'Impressora desconectada');
                },
              ),
            ),
        },
      ),
    );
  }
}

// ── Device list (shown when permission granted) ───────────────────────────

class _DeviceListView extends StatelessWidget {
  const _DeviceListView({
    required this.printer,
    required this.onScan,
    required this.onConnect,
    required this.onDisconnect,
  });

  final PrinterState printer;
  final VoidCallback onScan;
  final ValueChanged<BluetoothInfo> onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _StatusCard(printer: printer, onDisconnect: onDisconnect),
      const SizedBox(height: 16),
      const _HelpCard(),
      const SizedBox(height: 24),
      const Text(
        'Dispositivos pareados',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppPatioColors.textSecondary,
        ),
      ),
      const SizedBox(height: 8),
      if (printer.isScanning)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (printer.devices.isEmpty)
        _EmptyDevices(onScan: onScan)
      else ...[
        ...printer.devices.map(
          (d) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _DeviceTile(
              device: d,
              isConnected: printer.connectedMac == d.macAdress,
              onConnect: () => onConnect(d),
              onDisconnect: onDisconnect,
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onScan,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Atualizar lista'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppPatioColors.primary,
            side: const BorderSide(color: AppPatioColors.primary),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    ],
  );
}

// ── Permission gate card ──────────────────────────────────────────────────

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 64, color: AppPatioColors.textSecondary),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppPatioColors.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            color: AppPatioColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppPatioColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: onTap,
            icon: const Icon(Icons.bluetooth_rounded),
            label: Text(buttonLabel),
          ),
        ),
      ],
    ),
  );
}

// ── Status card ───────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.printer, required this.onDisconnect});
  final PrinterState printer;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final color = printer.isConnected
        ? AppPatioColors.success
        : AppPatioColors.textSecondary;
    final label = printer.isConnected
        ? printer.connectedName ?? printer.connectedMac ?? 'Conectado'
        : 'Sem impressora conectada';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPatioColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPatioColors.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              printer.isConnected
                  ? Icons.print_rounded
                  : Icons.print_disabled_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                if (printer.isConnected && printer.connectedMac != null)
                  Text(
                    printer.connectedMac!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppPatioColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (printer.isConnected)
            TextButton(
              onPressed: onDisconnect,
              child: const Text(
                'Desconectar',
                style: TextStyle(color: AppPatioColors.danger),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Help card ─────────────────────────────────────────────────────────────

class _HelpCard extends StatelessWidget {
  const _HelpCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppPatioColors.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      border:
          Border.all(color: AppPatioColors.primary.withValues(alpha: 0.2)),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline_rounded,
            size: 20, color: AppPatioColors.primary),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Ligue a impressora e pareie no Bluetooth do Android antes de conectar aqui.',
            style: TextStyle(fontSize: 13, color: AppPatioColors.primary),
          ),
        ),
      ],
    ),
  );
}

// ── Empty devices ─────────────────────────────────────────────────────────

class _EmptyDevices extends StatelessWidget {
  const _EmptyDevices({required this.onScan});
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Nenhum dispositivo Bluetooth pareado.',
          style:
              TextStyle(color: AppPatioColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ),
      FilledButton.icon(
        onPressed: onScan,
        icon: const Icon(Icons.bluetooth_searching_rounded),
        label: const Text('Buscar dispositivos'),
        style: FilledButton.styleFrom(
          backgroundColor: AppPatioColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    ],
  );
}

// ── Device tile ───────────────────────────────────────────────────────────

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.isConnected,
    required this.onConnect,
    required this.onDisconnect,
  });

  final BluetoothInfo device;
  final bool isConnected;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppPatioColors.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isConnected
            ? AppPatioColors.success.withValues(alpha: 0.4)
            : AppPatioColors.outline,
        width: isConnected ? 1.5 : 1,
      ),
    ),
    child: Row(
      children: [
        Icon(
          Icons.print_rounded,
          color: isConnected
              ? AppPatioColors.success
              : AppPatioColors.textSecondary,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppPatioColors.onSurface,
                ),
              ),
              Text(
                device.macAdress,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppPatioColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (isConnected)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppPatioColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Conectado',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppPatioColors.success,
              ),
            ),
          )
        else
          TextButton(
            onPressed: onConnect,
            style:
                TextButton.styleFrom(foregroundColor: AppPatioColors.primary),
            child: const Text('Conectar'),
          ),
      ],
    ),
  );
}
