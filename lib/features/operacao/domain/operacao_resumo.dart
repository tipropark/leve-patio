class OperacaoResumo {
  const OperacaoResumo({
    required this.id,
    required this.nome,
    required this.codigo,
  });

  final String id;
  final String nome;
  final String codigo;

  factory OperacaoResumo.fromJson(Map<String, dynamic> json) => OperacaoResumo(
    id:     json['id']     as String,
    nome:   json['nome']   as String,
    codigo: json['codigo'] as String,
  );
}
