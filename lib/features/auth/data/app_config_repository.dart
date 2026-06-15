import 'package:dio/dio.dart';

import '../../../core/config/env.dart';

class AppConfig {
  const AppConfig({
    required this.minVersion,
    this.forceUpdate = true,
  });
  final String minVersion;
  final bool forceUpdate;
}

class AppConfigRepository {
  AppConfigRepository({required this.dio});
  final Dio dio;

  Future<AppConfig> fetch() async {
    final resp = await dio.get(Env.appConfigUrl);
    final data = resp.data as Map<String, dynamic>;
    return AppConfig(
      minVersion:  data['min_version']  as String? ?? '1.0.0',
      forceUpdate: data['force_update'] as bool?   ?? true,
    );
  }
}
