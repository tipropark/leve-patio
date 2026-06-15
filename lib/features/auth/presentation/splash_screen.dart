import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_patio_colors.dart';
import '../../../core/widgets/patio_background.dart';
import 'providers/startup_notifier.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(startupProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor:          Colors.transparent,
        statusBarBrightness:     Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppPatioColors.background,
        body: PatioBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo P gold
                _SplashLogo(),
                const SizedBox(height: 20),
                const Text(
                  'Leve Pátio',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppPatioColors.secondary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Carregando…',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppPatioColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 40),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppPatioColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppPatioColors.secondary.withValues(alpha: 0.1),
            ),
          ),
          Transform.rotate(
            angle: 0.2,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppPatioColors.secondary, width: 3),
                color: AppPatioColors.surfaceContainerLow,
                boxShadow: [
                  BoxShadow(
                    color: AppPatioColors.secondary.withValues(alpha: 0.2),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          const Text(
            'P',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: AppPatioColors.secondary,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
