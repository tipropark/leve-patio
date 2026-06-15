import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leve_core/leve_core.dart';

import '../../../core/config/env.dart';
import '../../../core/di/providers.dart';
import '../../../core/theme/app_patio_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/patio_background.dart';
import 'providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _form          = GlobalKey<FormState>();
  final _matriculaCtrl = TextEditingController();
  final _senhaCtrl     = TextEditingController();

  bool _loading      = false;
  bool _ocultarSenha = true;

  String? _shortCode;
  String? _patioNome;
  String? _patioCodigo;
  bool    _loadingPatio = true;

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;

  static String _toShortCode(String uuid) =>
      uuid.replaceAll('-', '').substring(0, 8).toUpperCase();

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _carregarDispositivo();
  }

  Future<void> _carregarDispositivo() async {
    if (mounted) setState(() => _loadingPatio = true);

    final storage    = ref.read(tokenStorageProvider);
    final deviceUuid = await storage.getOrCreateDeviceUuid();
    if (mounted) setState(() => _shortCode = _toShortCode(deviceUuid));

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final resp = await dio.get(
        '${Env.apiBaseUrl}${Env.dispositivoInfoUrl}',
        options: Options(
          headers: {'X-Device-Id': deviceUuid},
          validateStatus: (s) => s != null && s < 600,
        ),
      );
      if (resp.statusCode == 200 && mounted) {
        final data   = resp.data as Map<String, dynamic>;
        final nome   = data['nome_operacao']   as String? ?? '';
        final codigo = data['codigo_operacao'] as String? ?? '';
        setState(() { _patioNome = nome; _patioCodigo = codigo; _loadingPatio = false; });
        await storage.savePatioVinculado(nome: nome, codigo: codigo);
        return;
      }
    } catch (_) {}

    final nomeCache   = await storage.readPatioNome();
    final codigoCache = await storage.readPatioCodigo();
    if (mounted) {
      setState(() { _patioNome = nomeCache; _patioCodigo = codigoCache; _loadingPatio = false; });
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _matriculaCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).login(
        matricula: _matriculaCtrl.text.trim().toUpperCase(),
        password:  _senhaCtrl.text,
      );
    } on ApiException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    } catch (_) {
      if (mounted) AppToast.error(context, 'Erro ao conectar. Verifique sua internet.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor:           Colors.transparent,
        statusBarBrightness:      Brightness.dark,
        statusBarIconBrightness:  Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppPatioColors.background,
        body: PatioBackground(
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom -
                        48,
                  ),
                  child: IntrinsicHeight(
                    child: Form(
                      key: _form,
                      child: Column(
                        children: [
                          const SizedBox(height: 48),

                          // ── Logo ────────────────────────────────────────────
                          _GoldLogo(),
                          const SizedBox(height: 16),

                          // ── Título ─────────────────────────────────────────
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
                            'Sistema de Gestão Operacional',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppPatioColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 36),

                          // ── Formulário glass ────────────────────────────────
                          GlassCard(
                            padding: const EdgeInsets.all(20),
                            borderRadius: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Matrícula
                                const _GlassLabel('Matrícula Operacional'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _matriculaCtrl,
                                  keyboardType: TextInputType.text,
                                  textInputAction: TextInputAction.next,
                                  textCapitalization: TextCapitalization.characters,
                                  autocorrect: false,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppPatioColors.onSurface,
                                    letterSpacing: 1.5,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Ex: OP-7492',
                                    prefixIcon: Icon(Icons.badge_outlined, color: AppPatioColors.onSurfaceVariant),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty) ? 'Informe a matrícula' : null,
                                ),
                                const SizedBox(height: 20),

                                // Senha
                                const _GlassLabel('Código de Acesso'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _senhaCtrl,
                                  obscureText: _ocultarSenha,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _login(),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    color: AppPatioColors.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '••••••••',
                                    prefixIcon: const Icon(Icons.lock_outline, color: AppPatioColors.onSurfaceVariant),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _ocultarSenha
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: AppPatioColors.onSurfaceVariant,
                                      ),
                                      onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha),
                                    ),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.isEmpty) ? 'Informe a senha' : null,
                                ),
                                const SizedBox(height: 24),

                                // Botão entrar
                                SizedBox(
                                  height: 52,
                                  child: FilledButton.icon(
                                    onPressed: _loading ? null : _login,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppPatioColors.secondary,
                                      foregroundColor: AppPatioColors.onSecondary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 0,
                                    ),
                                    icon: _loading
                                        ? const SizedBox(
                                            width: 20, height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppPatioColors.onSecondary),
                                          )
                                        : const Icon(Icons.login_rounded, size: 20),
                                    label: const Text(
                                      'Entrar no Sistema',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () {},
                                  style: TextButton.styleFrom(foregroundColor: AppPatioColors.onSurfaceVariant),
                                  child: const Text('Problemas com o acesso?'),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),
                          const SizedBox(height: 24),

                          // ── Card dispositivo ────────────────────────────────
                          _DeviceCard(
                            shortCode:    _shortCode,
                            patioNome:    _patioNome,
                            patioCodigo:  _patioCodigo,
                            loadingPatio: _loadingPatio,
                            onRefresh:    _carregarDispositivo,
                          ),

                          const SizedBox(height: 8),
                          Text(
                            Env.versionDisplay,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppPatioColors.outline,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Logo dourado geométrico ──────────────────────────────────────────────────

class _GoldLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppPatioColors.secondary.withValues(alpha: 0.12),
            ),
          ),
          // Box rotacionado
          Transform.rotate(
            angle: 0.2, // ~12 graus
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppPatioColors.secondary, width: 3),
                color: AppPatioColors.surfaceContainerLow,
                boxShadow: [
                  BoxShadow(
                    color: AppPatioColors.secondary.withValues(alpha: 0.25),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          // Letra P
          const Text(
            'P',
            style: TextStyle(
              fontSize: 28,
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

// ── Label para inputs ────────────────────────────────────────────────────────

class _GlassLabel extends StatelessWidget {
  const _GlassLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppPatioColors.onSurfaceVariant,
      letterSpacing: 0.02,
    ),
  );
}

// ── Card de dispositivo ──────────────────────────────────────────────────────

class _DeviceCard extends StatefulWidget {
  const _DeviceCard({
    required this.shortCode,
    required this.patioNome,
    required this.patioCodigo,
    required this.loadingPatio,
    this.onRefresh,
  });

  final String?       shortCode;
  final String?       patioNome;
  final String?       patioCodigo;
  final bool          loadingPatio;
  final VoidCallback? onRefresh;

  @override
  State<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<_DeviceCard> {
  bool _copiado = false;

  Future<void> _copiar() async {
    if (widget.shortCode == null) return;
    await Clipboard.setData(ClipboardData(text: widget.shortCode!));
    if (!mounted) return;
    setState(() => _copiado = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copiado = false);
  }

  @override
  Widget build(BuildContext context) {
    final vinculado = widget.patioNome != null && widget.patioNome!.isNotEmpty;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 12,
      fillColor: AppPatioColors.glassFill.withValues(alpha: 0.08),
      borderColor: AppPatioColors.glassHighBorder,
      child: Row(
        children: [
          // Ícone pátio
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppPatioColors.surfaceContainer,
              border: Border.all(color: AppPatioColors.glassBorder),
            ),
            child: const Icon(
              Icons.warehouse_rounded,
              size: 18,
              color: AppPatioColors.secondary,
            ),
          ),
          const SizedBox(width: 12),

          // Informações
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PÁTIO VINCULADO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppPatioColors.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                widget.loadingPatio
                    ? const SizedBox(
                        height: 14,
                        child: LinearProgressIndicator(
                          backgroundColor: AppPatioColors.glassBorder,
                          color: AppPatioColors.secondary,
                        ),
                      )
                    : Text(
                        vinculado ? widget.patioNome! : 'Não vinculado',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: vinculado
                              ? AppPatioColors.onSurface
                              : AppPatioColors.outline,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                if (widget.shortCode != null)
                  GestureDetector(
                    onTap: _copiar,
                    child: Text(
                      _copiado ? 'Copiado!' : 'ID: ${widget.shortCode}',
                      style: TextStyle(
                        fontSize: 10,
                        color: _copiado
                            ? AppPatioColors.success
                            : AppPatioColors.outline,
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Botão sync
          if (widget.onRefresh != null)
            widget.loadingPatio
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppPatioColors.onSurfaceVariant,
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.sync_rounded, size: 20),
                    color: AppPatioColors.onSurfaceVariant,
                    onPressed: widget.onRefresh,
                    tooltip: 'Verificar novamente',
                  ),
        ],
      ),
    );
  }
}
