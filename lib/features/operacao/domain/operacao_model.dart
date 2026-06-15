import 'tarifa_config.dart';

class OperacaoModel {
  const OperacaoModel({
    required this.id,
    required this.nome,
    required this.codigo,
    required this.qtdVagas,
    required this.tiposVeiculo,
    required this.formasPagamento,
    required this.motivosIsencao,
    required this.motivosCancelamento,
    required this.tarifas,
    required this.sincronizadoEm,
  });

  final String id;
  final String nome;
  final String codigo;
  final int qtdVagas;
  final List<String> tiposVeiculo;
  final List<String> formasPagamento;
  final List<String> motivosIsencao;
  final List<String> motivosCancelamento;
  final List<TarifaConfig> tarifas;
  final DateTime sincronizadoEm;

  /// Retorna as tarifas vigentes para o tipo de veículo informado (todas).
  List<TarifaConfig> tarifasVigentes(String tipoVeiculo) =>
      tarifas
          .where((t) => t.tipoVeiculo == tipoVeiculo && t.vigente)
          .toList();

  /// Retorna as tarifas visíveis ao operador para o tipo de veículo,
  /// ordenadas por [ordem]. Usada na seleção de tabela de preço.
  List<TarifaConfig> tabelasVisiveis(String tipoVeiculo) {
    final lista = tarifas
        .where((t) =>
            t.tipoVeiculo == tipoVeiculo && t.vigente && t.visivelOperador)
        .toList()
      ..sort((a, b) => a.ordem.compareTo(b.ordem));
    return lista;
  }
}
