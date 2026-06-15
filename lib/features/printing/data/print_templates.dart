import 'package:intl/intl.dart';

import 'esc_pos_builder.dart';

abstract final class PrintTemplates {
  static final _fmt = DateFormat('dd/MM/yyyy HH:mm');
  static final _moeda =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ');

  static const int _w = 32; // printer column width (58mm ≈ 32 chars)

  // ── Ticket de Entrada ────────────────────────────────────────────────────

  static List<int> ticketEntrada({
    required String ticketId,
    required String placa,
    required String tipoVeiculo,
    required DateTime entrada,
    required String operacaoNome,
  }) {
    final shortId = ticketId.substring(0, 8).toUpperCase();

    return EscPosBuilder()
        .reset()
        .centerAlign()
        .boldOn()
        .line(operacaoNome.toUpperCase())
        .line('TICKET DE ENTRADA')
        .boldOff()
        .separator(width: _w)
        .leftAlign()
        .line(_row('Placa   :', placa))
        .line(_row('Tipo    :', _capitalize(tipoVeiculo)))
        .line(_row('Entrada :', _fmt.format(entrada)))
        .separator(width: _w)
        .centerAlign()
        .line('ID: $shortId')
        .separator(width: _w)
        .line('Guarde este cupom.')
        .line('Apresente na saida.')
        .cut()
        .build();
  }

  // ── Recibo de Saída ──────────────────────────────────────────────────────

  static List<int> reciboSaida({
    required String placa,
    required String tipoVeiculo,
    required DateTime entrada,
    required DateTime saida,
    required double valorCobrado,
    required String formaPagamento,
    required String operacaoNome,
    bool isIsento = false,
  }) {
    final duracao   = saida.difference(entrada);
    final h = duracao.inHours;
    final m = duracao.inMinutes.remainder(60);
    final duracaoStr = h > 0 ? '${h}h ${m}min' : '${m}min';

    return EscPosBuilder()
        .reset()
        .centerAlign()
        .boldOn()
        .line(operacaoNome.toUpperCase())
        .line('RECIBO DE SAIDA')
        .boldOff()
        .separator(width: _w)
        .leftAlign()
        .line(_row('Placa    :', placa))
        .line(_row('Tipo     :', _capitalize(tipoVeiculo)))
        .line(_row('Entrada  :', _fmt.format(entrada)))
        .line(_row('Saida    :', _fmt.format(saida)))
        .line(_row('Tempo    :', duracaoStr))
        .separator(width: _w)
        .boldOn()
        .line(_row(isIsento ? 'Isento   :' : 'Valor    :', _moeda.format(valorCobrado)))
        .boldOff()
        .line(_row('Pagamento:', _capitalize(formaPagamento)))
        .separator(width: _w)
        .centerAlign()
        .line('Obrigado!')
        .cut()
        .build();
  }

  // ── Fechamento de Caixa ──────────────────────────────────────────────────

  static List<int> fechamentoCaixa({
    required String operadorNome,
    required String operacaoNome,
    required DateTime abertura,
    required DateTime fechamento,
    required double fundoCaixa,
    required double totalEntradas,
    required double totalSangrias,
    required double totalCalculado,
    required double totalContado,
    required double divergencia,
  }) {
    final divStr = divergencia > 0.01
        ? '+${_moeda.format(divergencia)} (excesso)'
        : divergencia < -0.01
            ? '${_moeda.format(divergencia)} (falta)'
            : 'R\$ 0,00 (OK)';

    return EscPosBuilder()
        .reset()
        .centerAlign()
        .boldOn()
        .line(operacaoNome.toUpperCase())
        .line('FECHAMENTO DE CAIXA')
        .boldOff()
        .separator(width: _w)
        .leftAlign()
        .line(_row('Operador :', operadorNome))
        .line(_row('Abertura :', _fmt.format(abertura)))
        .line(_row('Fechament:', _fmt.format(fechamento)))
        .separator(width: _w)
        .line(_row('Fundo    :', _moeda.format(fundoCaixa)))
        .line(_row('Entradas :', _moeda.format(totalEntradas)))
        .line(_row('Sangrias :', '-${_moeda.format(totalSangrias)}'))
        .separator(width: _w)
        .line(_row('Calculado:', _moeda.format(totalCalculado)))
        .line(_row('Contado  :', _moeda.format(totalContado)))
        .boldOn()
        .line(_row('Diferenca:', divStr))
        .boldOff()
        .separator(width: _w)
        .cut()
        .build();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Formats a two-column row that fills [_w] characters total.
  static String _row(String label, String value) {
    final padding = _w - label.length - value.length;
    return padding > 0
        ? '$label${' ' * padding}$value'
        : '$label $value';
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}
