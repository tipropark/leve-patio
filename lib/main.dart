import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_patio_theme.dart';
import 'features/auth/presentation/providers/version_gate_notifier.dart';
import 'features/operacao/presentation/providers/bootstrap_lifecycle_notifier.dart';
import 'features/sync/presentation/sync_lifecycle_notifier.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: LevePatioApp()));
}

class LevePatioApp extends ConsumerWidget {
  const LevePatioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ativa o listener que dispara bootstrap quando o auth transiciona para LoggedIn.
    ref.watch(bootstrapLifecycleProvider);
    ref.watch(syncLifecycleProvider);
    ref.watch(versionGateProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Leve Pátio',
      theme: AppPatioTheme.theme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
    );
  }
}
