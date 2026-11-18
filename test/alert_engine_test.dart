import 'package:flutter_test/flutter_test.dart';
import 'package:territorio_vivo/data/models.dart';
import 'package:territorio_vivo/data/territory.dart';
import 'package:territorio_vivo/domain/alert_engine.dart';
import 'package:territorio_vivo/domain/social_impact.dart';

final _start = DateTime(2026, 11, 1);
final _now = DateTime(2026, 11, 1 + 30);

Indicator _ind(String id, List<double> values, {List<double> forecast = const []}) =>
    Indicator(
      spec: IndicatorSpec.byId(id),
      history: [
        for (var i = 0; i < values.length; i++)
          DataPoint(DateTime(_start.year, _start.month, _start.day + i), values[i]),
      ],
      forecast: [
        for (var i = 0; i < forecast.length; i++)
          DataPoint(DateTime(_now.year, _now.month, _now.day + i), forecast[i]),
      ],
    );

List<Alert> _run(Indicator ind, double threshold, {bool fromCache = false}) =>
    AlertEngine.generate(
      indicators: [ind],
      thresholds: {ind.id: threshold},
      generatedAt: _now,
      fromCache: fromCache,
    );

void main() {
  group('linearTrend', () {
    test('recupera uma reta perfeita', () {
      final t = linearTrend([1, 3, 5, 7]);
      expect(t.slope, closeTo(2, 1e-9));
      expect(t.intercept, closeTo(1, 1e-9));
      expect(t.r2, closeTo(1, 1e-9));
    });

    test('série constante tem inclinação e R² zero', () {
      final t = linearTrend([5, 5, 5, 5]);
      expect(t.slope, 0);
      expect(t.r2, 0);
    });
  });

  group('AlertEngine', () {
    test('valores estáveis abaixo do limiar não geram alerta', () {
      expect(_run(_ind('agua', List.filled(30, 900.0)), 950), isEmpty);
    });

    test('limiar ultrapassado gera alerta com evidência, confiança e limitações', () {
      final alerts = _run(_ind('agua', [...List.filled(20, 900.0), 1000.0]), 950);
      expect(alerts, hasLength(1));
      final a = alerts.single;
      expect(a.kind, AlertKind.limiar);
      expect(a.severity, Severity.atencao);
      expect(a.confidence, Confidence.alta);
      expect(a.evidence, isNotEmpty);
      expect(a.limitations, isNotEmpty);
      expect(a.limitations.join(), contains('sintéticos'));
    });

    test('20% acima do limiar é crítico', () {
      final a = _run(_ind('agua', [...List.filled(20, 900.0), 1200.0]), 950).single;
      expect(a.severity, Severity.critico);
    });

    test('previsão oficial acima do limiar gera alerta de previsão', () {
      final ind = _ind('temp_max', List.filled(20, 26.0), forecast: [28, 30, 34]);
      final a = _run(ind, 32).single;
      expect(a.kind, AlertKind.previsao);
      expect(a.summary, contains('em 2 dias'));
      expect(a.confidence, Confidence.media);
    });

    test('tendência de alta consistente projeta o cruzamento do limiar', () {
      final values = [for (var i = 0; i < 14; i++) 1000.0 + 10 * i]; // até 1130
      final a = _run(_ind('ubs', values), 1160).single;
      expect(a.kind, AlertKind.tendencia);
      expect(a.summary, contains('3 dia(s)'));
      expect(a.confidence, Confidence.alta);
    });

    test('tendência fraca (R² baixo) não gera alerta', () {
      final noisy = [for (var i = 0; i < 14; i++) i.isEven ? 900.0 : 1000.0];
      expect(_run(_ind('ubs', noisy), 1050), isEmpty);
    });

    test('dados do cache e histórico curto reduzem a confiança', () {
      final online = _run(_ind('agua', [...List.filled(20, 900.0), 1000.0]), 950).single;
      final offline =
          _run(_ind('agua', [...List.filled(20, 900.0), 1000.0]), 950, fromCache: true)
              .single;
      final short = _run(_ind('agua', [900, 900, 1000]), 950).single;
      expect(offline.confidenceScore, lessThan(online.confidenceScore));
      expect(short.confidenceScore, lessThan(online.confidenceScore));
      expect(offline.limitations.join(), contains('Sem conexão'));
      expect(short.limitations.join(), contains('Histórico curto'));
    });

    test('ordena por severidade', () {
      final alerts = AlertEngine.generate(
        indicators: [
          _ind('agua', [...List.filled(20, 900.0), 1000.0]), // atenção
          _ind('energia', [...List.filled(20, 4000.0), 6000.0]), // crítico
        ],
        thresholds: IndicatorSpec.defaultThresholds,
        generatedAt: _now,
      );
      expect(alerts.map((a) => a.severity).toList(), [Severity.critico, Severity.atencao]);
    });
  });

  test('impacto social soma apenas alertas revisados, sem duplicar', () {
    final alerts = AlertEngine.generate(
      indicators: [
        _ind('agua', [...List.filled(20, 900.0), 1000.0]),
        _ind('energia', [...List.filled(20, 4000.0), 6000.0]),
      ],
      thresholds: IndicatorSpec.defaultThresholds,
      generatedAt: _now,
    );
    final agua = alerts.firstWhere((a) => a.spec.id == 'agua');
    final energia = alerts.firstWhere((a) => a.spec.id == 'energia');
    final impact = SocialImpact.compute(alerts, {
      agua.id: AlertDecision(
          status: DecisionStatus.revisado, note: '', decidedAt: _now),
      energia.id: AlertDecision(
          status: DecisionStatus.descartado, note: '', decidedAt: _now),
    });
    expect(impact.peopleBenefited, IndicatorSpec.byId('agua').beneficiaries);
    expect(impact.decided, 2);
    expect(impact.supervisionRate, 1);
  });
}
