abstract final class VersionUtils {
  /// Returns true if [current] is older than [minimum].
  static bool isUpdateRequired(String current, String minimum) {
    final c = _parse(current);
    final m = _parse(minimum);
    for (var i = 0; i < 3; i++) {
      if (c[i] < m[i]) return true;
      if (c[i] > m[i]) return false;
    }
    return false;
  }

  static List<int> _parse(String v) {
    final parts = v.replaceAll(RegExp(r'[^0-9.]'), '').split('.');
    return List.generate(
      3,
      (i) => i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0,
    );
  }
}
