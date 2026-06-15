/// Utilitários de formatação de labels para exibição ao usuário.
abstract final class LabelUtils {
  /// Converte um identificador de forma de pagamento em label amigável.
  /// Ex: "cartao_credito" → "Cartão de Crédito", "pix" → "Pix"
  static String formaPagamento(String raw) => switch (raw.toLowerCase().trim()) {
    'dinheiro'                  => 'Dinheiro',
    'pix'                       => 'Pix',
    'cartao' || 'cartão'        => 'Cartão',
    'cartao_credito'
    || 'cartão_crédito'
    || 'credito'
    || 'crédito'                => 'Cartão de Crédito',
    'cartao_debito'
    || 'cartão_débito'
    || 'debito'
    || 'débito'                 => 'Cartão de Débito',
    'cheque'                    => 'Cheque',
    'transferencia'
    || 'transferência'          => 'Transferência',
    'boleto'                    => 'Boleto',
    'voucher'                   => 'Voucher',
    'mensalidade'               => 'Mensalidade',
    _ => _fromSnakeCase(raw),
  };

  /// Converte qualquer string snake_case em "Título Com Espaços".
  static String _fromSnakeCase(String s) => s
      .split(RegExp(r'[_\s]+'))
      .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}
