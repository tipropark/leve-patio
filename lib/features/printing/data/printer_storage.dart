import 'package:leve_core/leve_core.dart';

class PrinterStorage {
  PrinterStorage(this._secure);

  final SecureStorage _secure;

  static const _keyMac  = 'patio_printer_mac';
  static const _keyName = 'patio_printer_name';

  Future<String?> readMac()  => _secure.read(_keyMac);
  Future<String?> readName() => _secure.read(_keyName);

  Future<void> save({required String mac, required String name}) async {
    await _secure.write(_keyMac, mac);
    await _secure.write(_keyName, name);
  }

  Future<void> clear() async {
    await _secure.delete(_keyMac);
    await _secure.delete(_keyName);
  }
}
