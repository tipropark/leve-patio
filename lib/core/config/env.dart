class Env {
  Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://dashboard.levemobilidade.com.br',
  );

  static const String appId = String.fromEnvironment(
    'APP_ID',
    defaultValue: 'patio',
  );

  static const bool enableHttpLogs = bool.fromEnvironment(
    'HTTP_LOGS',
    defaultValue: true,
  );

  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  static const String buildNumber = String.fromEnvironment(
    'BUILD_NUMBER',
    defaultValue: '0',
  );

  static const String gitSha = String.fromEnvironment(
    'GIT_SHA',
    defaultValue: 'dev',
  );

  static String get versionDisplay {
    const build = buildNumber != '0' ? '+$buildNumber' : '';
    const sha = gitSha != 'dev' ? ' ($gitSha)' : '';
    return 'v$appVersion$build$sha';
  }

  // Namespaces de API
  static const String _prefix = '/api/mobile/v1/patio';
  static String get authBase        => '$_prefix/auth';
  static String get bootstrapUrl    => '$_prefix/bootstrap';
  static String get syncUrl         => '$_prefix/sync';
  static String get dispositivoUrl      => '$_prefix/dispositivo';
  static String get dispositivoInfoUrl  => '$_prefix/dispositivo/info';
  static String get appConfigUrl    => '/api/mobile/v1/patio/app-config?app_id=$appId';

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Sync
  static const Duration syncInterval = Duration(minutes: 5);
  static const int syncMaxTentativas = 10;
}
