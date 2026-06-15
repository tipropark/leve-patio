class PatioUser {
  const PatioUser({
    required this.id,
    required this.nome,
    required this.matricula,
    required this.operacaoIds,
  });

  final String id;
  final String nome;
  final String matricula;
  final List<String> operacaoIds;

  factory PatioUser.fromJson(Map<String, dynamic> json) => PatioUser(
    id:          json['id']        as String,
    nome:        json['nome']      as String,
    matricula:   json['matricula'] as String,
    operacaoIds: (json['operacao_ids'] as List? ?? []).cast<String>(),
  );

  Map<String, dynamic> toJson() => {
    'id':           id,
    'nome':         nome,
    'matricula':    matricula,
    'operacao_ids': operacaoIds,
  };
}
