import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../theme/app_patio_colors.dart';

/// Bottom navigation glassmorphism — 4 abas principais.
class PatioBottomNav extends StatelessWidget {
  const PatioBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  static const _tabs = [
    _NavTab(icon: Icons.dashboard_rounded,      label: 'Início',  route: Routes.home),
    _NavTab(icon: Icons.local_parking_rounded,  label: 'Pátio',   route: Routes.patio),
    _NavTab(icon: Icons.payments_rounded,        label: 'Caixa',   route: Routes.aberturaCaixa),
    _NavTab(icon: Icons.settings_rounded,        label: 'Ajustes', route: Routes.ajustes),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xCC011230), // surface/80
            border: Border(top: BorderSide(color: AppPatioColors.glassBorder)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 60,
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final tab      = _tabs[i];
                  final isActive = i == currentIndex;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (!isActive) {
                          HapticFeedback.selectionClick();
                          context.go(tab.route);
                        }
                      },
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.08 * 10,
                          color: isActive
                              ? AppPatioColors.secondary
                              : AppPatioColors.onSurfaceVariant,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                tab.icon,
                                key: ValueKey(isActive),
                                size: 24,
                                color: isActive
                                    ? AppPatioColors.secondary
                                    : AppPatioColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(tab.label),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  const _NavTab({required this.icon, required this.label, required this.route});
  final IconData icon;
  final String   label;
  final String   route;
}
