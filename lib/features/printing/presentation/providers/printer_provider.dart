import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../../core/di/providers.dart';

// ── State ─────────────────────────────────────────────────────────────────

class PrinterState {
  const PrinterState({
    this.isConnected = false,
    this.connectedMac,
    this.connectedName,
    this.isScanning = false,
    this.isPrinting = false,
    this.devices = const [],
  });

  final bool isConnected;
  final String? connectedMac;
  final String? connectedName;
  final bool isScanning;
  final bool isPrinting;
  final List<BluetoothInfo> devices;

  PrinterState copyWith({
    bool? isConnected,
    String? connectedMac,
    String? connectedName,
    bool? isScanning,
    bool? isPrinting,
    List<BluetoothInfo>? devices,
    bool clearMac = false,
    bool clearName = false,
  }) =>
      PrinterState(
        isConnected:   isConnected   ?? this.isConnected,
        connectedMac:  clearMac      ? null : connectedMac  ?? this.connectedMac,
        connectedName: clearName     ? null : connectedName ?? this.connectedName,
        isScanning:    isScanning    ?? this.isScanning,
        isPrinting:    isPrinting    ?? this.isPrinting,
        devices:       devices       ?? this.devices,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────

class PrinterNotifier extends AsyncNotifier<PrinterState> {
  @override
  Future<PrinterState> build() async {
    final storage = ref.read(printerStorageProvider);
    final mac  = await storage.readMac();
    final name = await storage.readName();
    if (mac != null) {
      final ok = await ref.read(printerServiceProvider).connect(mac);
      if (ok) {
        return PrinterState(
          isConnected:   true,
          connectedMac:  mac,
          connectedName: name,
        );
      }
    }
    return const PrinterState();
  }

  Future<void> scan() async {
    final current = _current;
    state = AsyncData(current.copyWith(isScanning: true));
    try {
      final devices = await ref.read(printerServiceProvider).pairedDevices();
      state = AsyncData(current.copyWith(isScanning: false, devices: devices));
    } catch (_) {
      state = AsyncData(current.copyWith(isScanning: false));
    }
  }

  Future<void> connect(BluetoothInfo device) async {
    final current = _current;
    state = AsyncData(current.copyWith(isScanning: true));
    try {
      final ok = await ref.read(printerServiceProvider).connect(device.macAdress);
      if (ok) {
        await ref.read(printerStorageProvider).save(
          mac:  device.macAdress,
          name: device.name,
        );
        state = AsyncData(current.copyWith(
          isScanning:    false,
          isConnected:   true,
          connectedMac:  device.macAdress,
          connectedName: device.name,
        ));
      } else {
        state = AsyncData(current.copyWith(isScanning: false));
      }
    } catch (_) {
      state = AsyncData(current.copyWith(isScanning: false));
    }
  }

  Future<void> disconnect() async {
    await ref.read(printerServiceProvider).disconnect();
    await ref.read(printerStorageProvider).clear();
    state = AsyncData(_current.copyWith(
      isConnected: false,
      clearMac:    true,
      clearName:   true,
    ));
  }

  Future<bool> print(List<int> bytes) async {
    final current = _current;
    if (!current.isConnected) return false;
    state = AsyncData(current.copyWith(isPrinting: true));
    try {
      final ok = await ref.read(printerServiceProvider).printBytes(bytes);
      state = AsyncData(current.copyWith(isPrinting: false));
      return ok;
    } catch (_) {
      state = AsyncData(current.copyWith(isPrinting: false));
      return false;
    }
  }

  PrinterState get _current => switch (state) {
    AsyncData(:final value) => value,
    _ => const PrinterState(),
  };
}

// ── Provider ──────────────────────────────────────────────────────────────

final printerNotifierProvider =
    AsyncNotifierProvider<PrinterNotifier, PrinterState>(
  PrinterNotifier.new,
);
