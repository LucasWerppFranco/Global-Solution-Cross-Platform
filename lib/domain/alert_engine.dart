import 'dart:math' as math;

import '../core/format.dart';
import '../data/models.dart';
import '../data/territory.dart';

enum Severity {
  info('Informativo'),
  atencao('Atenção'),
  critico('Crítico');

  const Severity(this.label);
  final String label;
}

enum Confidence {
  baixa('Baixa'),
  media('Média'),
  alta('Alta');

  const Confidence(this.label);
  final String label;

  static Confidence fromScore(double s) =>
      s >= 0.75 ? alta : (s >= 0.5 ? media : baixa);
}

enum AlertKind {
  limiar('Limiar ultrapassado'),
  previsao('Previsão oficial'),
  tendencia('Tendência estatística');

  const AlertKind(this.label);
  final String label;
}

/// Alerta preditivo. Sempre carrega evidências, confiança e limitações —
/// e nunca dispara ação automática: só um humano registra a decisão.
class Alert {
  const Alert({
    required this.id,
    required this.spec,
    required this.kind,
    required this.severity,
    required this.confidenceScore,
    required this.confidenceRationale,
    required this.title,
    required this.summary,
    required this.evidence,
    required this.limitations,
    required this.generatedAt,
  });

  final String id;
  final IndicatorSpec spec;
  final AlertKind kind;
  final Severity severity;
  final double confidenceScore; // 0..1
  final String confidenceRationale;
  final String title;
  final String summary;
  final List<String> evidence;
  final List<String> limitations;
  final DateTime generatedAt;

  Confidence get confidence => Confidence.fromScore(confidenceScore);
  String get recommendation => spec.recommendation;
}

class Trend {
  const Trend(this.slope, this.intercept, this.r2);
  final double slope; // unidades por dia
  final double intercept;
  final double r2; // 0..1: quanto da variação a reta explica

  double at(num x) => intercept + slope * x;
}

/// Regressão linear simples (mínimos quadrados) com x = 0..n-1.
Trend linearTrend(List<double> ys) {
  final n = ys.length;
  if (n < 2) return Trend(0.0, n == 1 ? ys.first : 0.0, 0.0);
  final meanX = (n - 1) / 2;
  final meanY = ys.reduce((a, b) => a + b) / n;
  var sxy = 0.0, sxx = 0.0, syy = 0.0;
  for (var i = 0; i < n; i++) {
    final dx = i - meanX, dy = ys[i] - meanY;
    sxy += dx * dy;
    sxx += dx * dx;
    syy += dy * dy;
  }
  final slope = sxy / sxx;
  final r2 = syy == 0 ? 0.0 : (sxy * sxy) / (sxx * syy);
  return Trend(slope, meanY - slope * meanX, r2);
}

class Stats {
  const Stats(this.mean, this.std, this.min, this.max);
  final double mean, std, min, max;
}

Stats describe(List<double> ys) {
  final mean = ys.reduce((a, b) => a + b) / ys.length;
  final variance =
      ys.map((y) => (y - mean) * (y - mean)).reduce((a, b) => a + b) / ys.length;
  return Stats(mean, math.sqrt(variance), ys.reduce(math.min), ys.reduce(math.max));
}

List<T> _tail<T>(List<T> l, int n) => l.length <= n ? l : l.sublist(l.length - n);

/// Projeção linear dos próximos [days] dias a partir da janela recente.
List<DataPoint> projectLinear(List<DataPoint> history,
    {int days = AlertEngine.horizonDays}) {
  final window = _tail(history, AlertEngine.trendWindow);
  final t = linearTrend([for (final p in window) p.value]);
  final last = history.last.date;
  return [
    for (var d = 1; d <= days; d++)
      DataPoint(DateTime(last.year, last.month, last.day + d),
          t.at(window.length - 1 + d)),
  ];
}

/// Gera no máximo um alerta por indicador, em ordem de prioridade:
/// 1. limiar já ultrapassado (valor observado);
/// 2. previsão oficial acima do limiar (apenas clima);
/// 3. tendência linear que cruza o limiar no horizonte de 7 dias.
abstract final class AlertEngine {
  static const trendWindow = 14;
  static const horizonDays = 7;
  static const minTrendPoints = 7;
  static const minR2 = 0.3;

  static List<Alert> generate({
    required List<Indicator> indicators,
    required Map<String, double> thresholds,
    required DateTime generatedAt,
    bool fromCache = false,
  }) {
    final alerts = <Alert>[];
    for (final ind in indicators) {
      final threshold = thresholds[ind.id] ?? ind.spec.defaultThreshold;
      final alert = _evaluate(ind, threshold, generatedAt, fromCache);
      if (alert != null) alerts.add(alert);
    }
    alerts.sort((a, b) {
      final bySeverity = b.severity.index.compareTo(a.severity.index);
      return bySeverity != 0
          ? bySeverity
          : b.confidenceScore.compareTo(a.confidenceScore);
    });
    return alerts;
  }

  static Alert? _evaluate(
      Indicator ind, double t, DateTime now, bool fromCache) {
    final spec = ind.spec;
    final values = [for (final p in ind.history) p.value];
    final recent = _tail(values, 30);
    final stats = describe(recent);
    final window = _tail(values, trendWindow);
    final trend = linearTrend(window);
    final ref = ind.history.last.date;
    String v(double x) => '${fmtNum(x, spec.decimals)} ${spec.unit}';

    // Evidências comuns a todos os tipos de alerta.
    final baseEvidence = [
      'Média dos últimos ${recent.length} dias: ${v(stats.mean)} '
          '(mín. ${v(stats.min)}, máx. ${v(stats.max)}).',
      'Tendência recente (${window.length} dias): '
          '${fmtSigned(trend.slope, spec.decimals + 1)} ${spec.unit}/dia, '
          'R² = ${fmtNum(trend.r2, 2)}.',
      if (stats.std > 0)
        'Último valor está a ${fmtSigned((ind.current - stats.mean) / stats.std, 1)} '
            'desvios-padrão da média.',
    ];

    // Limitações comuns + penalidades de confiança.
    var penalty = 1.0;
    final baseLimitations = [
      spec.limitation,
      if (spec.synthetic)
        'Dados sintéticos gerados para demonstração: não representam medições reais.',
    ];
    if (values.length < trendWindow) {
      penalty *= 0.8;
      baseLimitations.add(
          'Histórico curto (${values.length} dias): estatísticas pouco estáveis.');
    }
    if (fromCache) {
      penalty *= 0.75;
      baseLimitations.add(
          'Sem conexão: calculado com dados salvos, que podem estar desatualizados.');
    }
    baseLimitations.add(
        'Fatores não medidos (eventos, obras, feriados, falhas de medição) podem alterar o cenário.');

    Alert make({
      required AlertKind kind,
      required Severity severity,
      required double score,
      required String rationale,
      required String title,
      required String summary,
      required List<String> evidence,
      List<String> limitations = const [],
    }) =>
        Alert(
          id: '${spec.id}-${kind.name}-${dateKey(ref)}',
          spec: spec,
          kind: kind,
          severity: severity,
          confidenceScore: (score * penalty).clamp(0.0, 1.0).toDouble(),
          confidenceRationale: rationale,
          title: title,
          summary: summary,
          evidence: [...evidence, ...baseEvidence],
          limitations: [...limitations, ...baseLimitations],
          generatedAt: now,
        );

    // 1. Limiar já ultrapassado.
    if (ind.current >= t) {
      final ratio = ind.current / t;
      return make(
        kind: AlertKind.limiar,
        severity: ratio >= 1.2 ? Severity.critico : Severity.atencao,
        score: 0.9,
        rationale:
            'Baseada em valor já observado: a incerteza vem da qualidade e da atualidade da fonte.',
        title: '${spec.name} acima do limiar',
        summary: 'Último valor (${fmtDate(ref)}) de ${v(ind.current)} supera o '
            'limiar de ${v(t)} em ${fmtNum((ratio - 1) * 100, 0)}%.',
        evidence: [
          'Valor observado em ${fmtDate(ref)}: ${v(ind.current)}.',
          'Limiar configurado pelo gestor: ${v(t)}.',
        ],
      );
    }

    // 2. Previsão oficial (modelo meteorológico) acima do limiar.
    final hit = ind.forecast.where((p) => p.value >= t).firstOrNull;
    if (hit != null) {
      final ahead = math.max(0, daysBetween(now, hit.date));
      final peak = ind.forecast.reduce((a, b) => b.value > a.value ? b : a);
      return make(
        kind: AlertKind.previsao,
        severity: hit.value / t >= 1.2 ? Severity.critico : Severity.atencao,
        score: ahead <= 1 ? 0.85 : (ahead <= 3 ? 0.65 : 0.45),
        rationale:
            'Baseada na antecedência da previsão: até 1 dia = alta, até 3 dias = média, mais = baixa.',
        title: '${spec.name}: previsão acima do limiar',
        summary: 'O modelo meteorológico prevê ${v(hit.value)} para '
            '${fmtDate(hit.date)} (${fmtRelativeDay(ahead)}), acima do limiar de ${v(t)}.',
        evidence: [
          'Previsão para ${fmtDate(hit.date)}: ${v(hit.value)} (limiar ${v(t)}).',
          'Pico previsto nos próximos ${ind.forecast.length} dias: '
              '${v(peak.value)} em ${fmtDate(peak.date)}.',
        ],
        limitations: [
          'Previsões perdem precisão com a antecedência; esta se refere a ${fmtRelativeDay(ahead)}.',
        ],
      );
    }

    // 3. Tendência linear que cruza o limiar no horizonte.
    if (values.length >= minTrendPoints && trend.slope > 0 && trend.r2 >= minR2) {
      for (var d = 1; d <= horizonDays; d++) {
        final projected = trend.at(window.length - 1 + d);
        if (projected < t) continue;
        final date = DateTime(ref.year, ref.month, ref.day + d);
        return make(
          kind: AlertKind.tendencia,
          severity: d <= 3 ? Severity.atencao : Severity.info,
          score: 0.35 + 0.5 * trend.r2,
          rationale:
              'Baseada no R² da regressão: quanto mais a reta explica a variação dos dados, maior a confiança.',
          title: '${spec.name}: tendência de alta',
          summary: 'Se o ritmo dos últimos ${window.length} dias continuar, o limiar '
              'de ${v(t)} será atingido em cerca de $d dia(s) (≈ ${fmtDate(date)}).',
          evidence: [
            'Regressão linear explica ${fmtNum(trend.r2 * 100, 0)}% da variação recente.',
            'Valor projetado para ${fmtDate(date)}: ${v(projected)} (limiar ${v(t)}).',
          ],
          limitations: [
            'A projeção linear supõe que o padrão recente continua; mudanças bruscas a invalidam.',
            if (trend.r2 < 0.6)
              'Ajuste moderado (R² < 0,6): há bastante variação não explicada pela tendência.',
          ],
        );
      }
    }
    return null;
  }
}
