import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';

/// Wrapper fino sobre o Dio configurado com Bearer + Refresh.
/// Obtido via [dioProvider].
class PatioApiClient {
  PatioApiClient(this.dio);
  final Dio dio;
}

final patioApiClientProvider = Provider<PatioApiClient>(
  (ref) => PatioApiClient(ref.read(dioProvider)),
);
