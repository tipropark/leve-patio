import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/dispositivo_revogado_screen.dart';
import '../../features/auth/presentation/dispositivo_nao_vinculado_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/ajustes/presentation/ajustes_screen.dart';
import '../../features/auth/presentation/update_screen.dart';
import '../../features/caixa/presentation/caixa_screen.dart';
import '../../features/caixa/presentation/fechamento_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/operacao/presentation/operacao_select_screen.dart';
import '../../features/printing/presentation/printer_settings_screen.dart';
import '../../features/printing/presentation/qr_scanner_screen.dart';
import '../../features/sync/presentation/sync_screen.dart';
import '../../features/tickets/presentation/cobranca_screen.dart';
import '../../features/tickets/presentation/entrada_screen.dart';
import '../../features/tickets/presentation/saida_screen.dart';
import '../../features/patio/presentation/patio_screen.dart';

abstract final class Routes {
  static const splash            = '/splash';
  static const login             = '/login';
  static const operacaoSelect    = '/operacao-select';
  static const revogado          = '/revogado';
  static const naoVinculado      = '/nao-vinculado';
  static const update            = '/update';
  static const home              = '/home';
  static const patio             = '/patio';
  static const aberturaCaixa     = '/abertura-caixa';
  static const caixaFechamento   = '/abertura-caixa/fechamento';
  static const entrada           = '/entrada';
  static const saida             = '/saida';
  static const sync              = '/sync';
  static const ajustes           = '/ajustes';
  static const impressora        = '/ajustes/impressora';
  static const qrScanner         = '/qr-scanner';
  static String saidaDetalhe(String id) => '/saida/$id';
}

final _rootKey = GlobalKey<NavigatorState>();

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final auth = _ref.read(authControllerProvider);
    final loc  = state.matchedLocation;

    if (loc == Routes.update) return null;

    return switch (auth) {
      AuthLoading()      => loc == Routes.splash         ? null : Routes.splash,
      AuthLoggedOut()    => loc == Routes.login          ? null : Routes.login,
      AuthRevogado()     => loc == Routes.revogado       ? null : Routes.revogado,
      AuthNeedOperacao()       => loc == Routes.operacaoSelect ? null : Routes.operacaoSelect,
      AuthDeviceNaoVinculado() => loc == Routes.naoVinculado  ? null : Routes.naoVinculado,
      AuthNeedsUpdate()  => loc == Routes.update         ? null : Routes.update,
      AuthLoggedIn()     =>
        (loc == Routes.login  ||
         loc == Routes.splash ||
         loc == Routes.revogado ||
         loc == Routes.naoVinculado ||
         loc == Routes.update ||
         loc == Routes.operacaoSelect)
            ? Routes.home
            : null,
    };
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.revogado,
        builder: (_, _) => const DispositivoRevogadoScreen(),
      ),
      GoRoute(
        path: Routes.naoVinculado,
        builder: (_, _) => const _NaoVinculadoWrapper(),
      ),
      GoRoute(
        path: Routes.operacaoSelect,
        builder: (_, _) => const _OperacaoSelectWrapper(),
      ),
      GoRoute(path: Routes.update, builder: (_, _) => const UpdateScreen()),
      GoRoute(path: Routes.home,   builder: (_, _) => const HomeScreen()),
      GoRoute(path: Routes.patio,  builder: (_, _) => const PatioScreen()),
      GoRoute(
        path: Routes.aberturaCaixa,
        builder: (_, _) => const CaixaScreen(),
        routes: [
          GoRoute(
            path: 'fechamento',
            parentNavigatorKey: _rootKey,
            builder: (_, _) => const FechamentoCaixaScreen(),
          ),
        ],
      ),
      GoRoute(path: Routes.entrada, builder: (_, _) => const EntradaScreen()),
      GoRoute(
        path: Routes.saida,
        builder: (_, _) => const SaidaScreen(),
        routes: [
          GoRoute(
            path: ':id',
            parentNavigatorKey: _rootKey,
            builder: (_, s) => CobrancaScreen(
              ticketId: s.pathParameters['id']!,
            ),
          ),
        ],
      ),
      GoRoute(path: Routes.sync, builder: (_, _) => const SyncScreen()),
      GoRoute(
        path: Routes.ajustes,
        builder: (_, _) => const AjustesScreen(),
        routes: [
          GoRoute(
            path: 'impressora',
            parentNavigatorKey: _rootKey,
            builder: (_, _) => const PrinterSettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.qrScanner,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const QrScannerScreen(),
      ),
    ],
  );
});

// ── Wrappers que leem o estado do AuthController ──────────────────────────

class _OperacaoSelectWrapper extends ConsumerWidget {
  const _OperacaoSelectWrapper();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    return switch (state) {
      AuthNeedOperacao(:final user, :final operacoes, :final isFirstLogin) =>
        OperacaoSelectScreen(
          user:         user,
          operacoes:    operacoes,
          isFirstLogin: isFirstLogin,
        ),
      _ => const _Placeholder('Selecionar Operação'),
    };
  }
}

class _NaoVinculadoWrapper extends ConsumerWidget {
  const _NaoVinculadoWrapper();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    return switch (state) {
      AuthDeviceNaoVinculado(:final user, :final deviceUuid, :final operacoes) =>
        DispositivoNaoVinculadoScreen(
          user:       user,
          deviceUuid: deviceUuid,
          operacoes:  operacoes,
        ),
      _ => const _Placeholder('Dispositivo'),
    };
  }
}

// ── Placeholder ───────────────────────────────────────────────────────────

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.name);
  final String name;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(name)),
    body: Center(child: Text(name, style: const TextStyle(fontSize: 24))),
  );
}
