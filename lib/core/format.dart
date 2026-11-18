/// Formatação no padrão pt-BR, sem dependência do pacote intl.
String fmtNum(double v, [int decimals = 1]) =>
    v.toStringAsFixed(decimals).replaceAll('.', ',');

String fmtSigned(double v, [int decimals = 1]) =>
    '${v >= 0 ? '+' : ''}${fmtNum(v, decimals)}';

/// 431106 -> "431.106"
String fmtInt(int v) {
  final s = v.abs().toString();
  final b = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

String _two(int n) => n.toString().padLeft(2, '0');

String fmtDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}';

String fmtFullDate(DateTime d) => '${fmtDate(d)}/${d.year}';

String fmtDateTime(DateTime d) =>
    '${fmtFullDate(d)} ${_two(d.hour)}:${_two(d.minute)}';

String dateKey(DateTime d) => '${d.year}${_two(d.month)}${_two(d.day)}';

const _weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
String fmtWeekday(DateTime d) => _weekdays[d.weekday - 1];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Diferença em dias de calendário (robusta a horário de verão).
int daysBetween(DateTime from, DateTime to) =>
    (dateOnly(to).difference(dateOnly(from)).inHours / 24).round();

String fmtRelativeDay(int days) => switch (days) {
      <= 0 => 'hoje',
      1 => 'amanhã',
      _ => 'em $days dias',
    };
