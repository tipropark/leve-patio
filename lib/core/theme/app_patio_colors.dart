import 'package:flutter/material.dart';

/// Paleta Leve Pátio — dark navy + vermelho (identidade Leve Mobilidade).
/// Destaque vermelho da logomarca; verde/laranja reservados a status operacional.
abstract final class AppPatioColors {
  // ── Fundos ─────────────────────────────────────────────────────────────────
  static const Color background             = Color(0xFF011230);
  static const Color surface               = Color(0xFF011230);
  static const Color surfaceContainerLowest = Color(0xFF000D27);
  static const Color surfaceContainerLow    = Color(0xFF091B39);
  static const Color surfaceContainer       = Color(0xFF0E1F3D);
  static const Color surfaceContainerHigh   = Color(0xFF192A48);
  static const Color surfaceContainerHighest = Color(0xFF253453);
  static const Color surfaceBright          = Color(0xFF293958);
  static const Color surfaceVariant         = Color(0xFF253453);

  // ── Texto sobre fundo ──────────────────────────────────────────────────────
  static const Color onSurface        = Color(0xFFD8E2FF);
  static const Color onBackground     = Color(0xFFD8E2FF);
  static const Color onSurfaceVariant = Color(0xFFC5C6CD);
  static const Color outline          = Color(0xFF8F9097);
  static const Color outlineVariant   = Color(0xFF44474D);

  // ── Primário (azul/navy) ──────────────────────────────────────────────────
  static const Color primary           = Color(0xFFB9C7E4);
  static const Color onPrimary         = Color(0xFF233148);
  static const Color primaryContainer  = Color(0xFF0A192F);
  static const Color onPrimaryContainer = Color(0xFF74829D);

  // ── Secundário / destaque (vermelho Leve) ─────────────────────────────────
  static const Color secondary          = Color(0xFFE30613); // vermelho logomarca
  static const Color onSecondary        = Color(0xFFFFFFFF); // texto sobre o vermelho
  static const Color secondaryContainer = Color(0xFFB00510);
  static const Color secondaryFixed     = Color(0xFFFF8A8A);
  static const Color secondaryFixedDim  = Color(0xFFE30613);

  // ── Semânticas ────────────────────────────────────────────────────────────
  static const Color success   = Color(0xFF4ADE80); // verde sync "ok"
  static const Color warning   = Color(0xFFFB923C); // laranja sync "warn"
  static const Color danger    = Color(0xFFF87171); // vermelho sync offline
  static const Color error     = Color(0xFFFFB4AB);
  static const Color onError   = Color(0xFF690005);

  // ── Ações de entrada/saída ────────────────────────────────────────────────
  static const Color entrada = secondary;    // gold fill
  static const Color saida   = Color(0xFFD8E2FF); // on-surface (glass+gold border)

  // ── Glassmorphism ─────────────────────────────────────────────────────────
  static const Color glassFill   = Color(0x0DFFFFFF); // rgba(255,255,255,0.05)
  static const Color glassBorder = Color(0x1FFFFFFF); // rgba(255,255,255,0.12)
  static const Color glassHighBorder = Color(0x14FFFFFF); // rgba(255,255,255,0.08)

  // ── Indicadores de sync ───────────────────────────────────────────────────
  static const Color syncOnline  = Color(0xFF4ADE80);
  static const Color syncPending = Color(0xFFFB923C);
  static const Color syncOffline = Color(0xFFF87171);

  // Legado — manter compatibilidade com código ainda não migrado
  static const Color info = Color(0xFFB9C7E4);
  static const Color onPrimary_ = Colors.white;
  static const Color onDanger   = Colors.white;
  static const Color onWarning  = Colors.white;
  static const Color onSuccess  = Colors.white;
  static const Color textSecondary = onSurfaceVariant;
}
