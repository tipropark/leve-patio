import 'package:flutter/material.dart';

import '../theme/app_patio_colors.dart';

/// Fundo atmosférico dark navy com gradiente radial sutil no topo.
/// Usado como Stack base em todas as telas do app.
class PatioBackground extends StatelessWidget {
  const PatioBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base navy
        const ColoredBox(color: AppPatioColors.background),
        // Gradiente radial atmosférico
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -1),
                radius: 1.2,
                colors: [
                  AppPatioColors.surfaceContainerHigh.withValues(alpha: 0.4),
                  AppPatioColors.background.withValues(alpha: 0.8),
                  AppPatioColors.surfaceContainerLowest,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        // Conteúdo
        child,
      ],
    );
  }
}
