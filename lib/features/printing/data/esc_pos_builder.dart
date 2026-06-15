import 'dart:convert';

/// Minimal ESC/POS byte builder for 58mm/80mm thermal printers.
class EscPosBuilder {
  final List<int> _bytes = [];

  EscPosBuilder reset() {
    _bytes
      ..addAll([0x1B, 0x40]) // Initialize printer
      ..addAll([0x1B, 0x74, 0x02]); // Code page CP850 (Western European)
    return this;
  }

  EscPosBuilder centerAlign() {
    _bytes.addAll([0x1B, 0x61, 0x01]);
    return this;
  }

  EscPosBuilder leftAlign() {
    _bytes.addAll([0x1B, 0x61, 0x00]);
    return this;
  }

  EscPosBuilder boldOn() {
    _bytes.addAll([0x1B, 0x45, 0x01]);
    return this;
  }

  EscPosBuilder boldOff() {
    _bytes.addAll([0x1B, 0x45, 0x00]);
    return this;
  }

  EscPosBuilder text(String s) {
    _bytes.addAll(latin1.encode(_normalize(s)));
    return this;
  }

  EscPosBuilder line(String s) => text('$s\n');

  EscPosBuilder feed([int n = 1]) {
    for (var i = 0; i < n; i++) {
      _bytes.add(0x0A);
    }
    return this;
  }

  EscPosBuilder separator({int width = 32, String char = '-'}) =>
      line(char * width);

  /// Partial cut with 3 blank lines before.
  EscPosBuilder cut() {
    feed(3);
    _bytes.addAll([0x1D, 0x56, 0x41, 0x10]);
    return this;
  }

  List<int> build() => List.unmodifiable(_bytes);

  /// Replaces Portuguese accented chars with ASCII equivalents for
  /// printers that don't support extended charset encoding.
  static String _normalize(String s) => s
      .replaceAll(RegExp('[ãâàáä]'), 'a')
      .replaceAll(RegExp('[ÃÂÀÁÄ]'), 'A')
      .replaceAll(RegExp('[éêèë]'), 'e')
      .replaceAll(RegExp('[ÉÊÈË]'), 'E')
      .replaceAll(RegExp('[íîìï]'), 'i')
      .replaceAll(RegExp('[ÍÎÌÏ]'), 'I')
      .replaceAll(RegExp('[õôòóö]'), 'o')
      .replaceAll(RegExp('[ÕÔÒÓÖ]'), 'O')
      .replaceAll(RegExp('[úûùü]'), 'u')
      .replaceAll(RegExp('[ÚÛÙÜ]'), 'U')
      .replaceAll('ç', 'c')
      .replaceAll('Ç', 'C')
      .replaceAll('ñ', 'n')
      .replaceAll('Ñ', 'N');
}
