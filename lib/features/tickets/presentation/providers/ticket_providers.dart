import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../operacao/presentation/providers/operacao_provider.dart';
import '../../domain/ticket_model.dart';

final ticketsAbertosProvider =
    FutureProvider.autoDispose<List<TicketModel>>((ref) async {
  final operacao = await ref.watch(operacaoNotifierProvider.future);
  if (operacao == null) return [];
  return ref.read(ticketRepositoryProvider).getTicketsAbertos(operacao.id);
});

final ticketByIdProvider =
    FutureProvider.autoDispose.family<TicketModel?, String>((ref, id) async {
  return ref.read(ticketRepositoryProvider).getById(id);
});
