import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_patio_colors.dart';
import 'providers/sync_provider.dart';

/// Badge shown in the HomeScreen AppBar. Taps open the sync detail screen.
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncAsync = ref.watch(syncNotifierProvider);

    return IconButton(
      tooltip: 'Sincronização',
      onPressed: () => context.push(Routes.sync),
      icon: syncAsync.when(
        loading: () => const _SpinningIcon(),
        error: (_, _) => const Icon(
          Icons.sync_problem_rounded,
          color: Colors.white,
        ),
        data: (sync) {
          if (sync.isSyncing) return const _SpinningIcon();
          if (sync.hasError) {
            return const Icon(Icons.sync_problem_rounded, color: Colors.white);
          }
          if (sync.pendingCount > 0) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.sync_rounded, color: Colors.white),
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppPatioColors.warning,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        sync.pendingCount > 9 ? '9+' : '${sync.pendingCount}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return const Icon(Icons.sync_rounded, color: Colors.white);
        },
      ),
    );
  }
}

class _SpinningIcon extends StatefulWidget {
  const _SpinningIcon();

  @override
  State<_SpinningIcon> createState() => _SpinningIconState();
}

class _SpinningIconState extends State<_SpinningIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _ctrl,
    child: const Icon(Icons.sync_rounded, color: Colors.white),
  );
}
