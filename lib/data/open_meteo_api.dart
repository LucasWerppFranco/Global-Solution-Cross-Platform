import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/format.dart';
import 'models.dart';
import 'territory.dart';

/// Dados reais e públicos de clima e qualidade do ar (https://open-meteo.com).
/// Não exige chave de API, então não há credenciais no repositório.
class OpenMeteoApi {
  OpenMeteoApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 12);

  Future<List<Indicator>> fetch() async {
    final common = {
      'latitude': '${Territory.latitude}',
      'longitude': '${Territory.longitude}',
      'timezone': 'America/Sao_Paulo',
    };
    final responses = await Future.wait([
      _get(Uri.https('api.open-meteo.com', '/v1/forecast', {
        ...common,
        'daily': 'temperature_2m_max,precipitation_sum',
        'past_days': '30',
        'forecast_days': '7',
      })),
      _get(Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
        ...common,
        'hourly': 'pm2_5',
        'past_days': '30',
        'forecast_days': '4',
      })),
    ]);

    final today = dateOnly(DateTime.now());
    final daily = responses[0]['daily'] as Map<String, dynamic>;
    final dates = [for (final t in daily['time'] as List) DateTime.parse(t as String)];
    final hourly = responses[1]['hourly'] as Map<String, dynamic>;
    final pm = _dailyMean(hourly['time'] as List, hourly['pm2_5'] as List);

    return [
      _split('temp_max', dates, daily['temperature_2m_max'] as List, today),
      _split('precip', dates, daily['precipitation_sum'] as List, today),
      _split('pm25', pm.keys.toList(), pm.values.toList(), today),
    ].whereType<Indicator>().toList();
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final res = await _client.get(uri).timeout(_timeout);
    if (res.statusCode != 200) {
      throw ApiException('Open-Meteo respondeu HTTP ${res.statusCode}.');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Dias anteriores a hoje viram histórico (observado); hoje em diante, previsão.
  Indicator? _split(
      String id, List<DateTime> dates, List<dynamic> values, DateTime today) {
    final history = <DataPoint>[];
    final forecast = <DataPoint>[];
    for (var i = 0; i < dates.length && i < values.length; i++) {
      final v = values[i];
      if (v is! num) continue; // a API devolve null em lacunas
      final p = DataPoint(dateOnly(dates[i]), v.toDouble());
      (p.date.isBefore(today) ? history : forecast).add(p);
    }
    if (history.isEmpty) return null;
    return Indicator(
        spec: IndicatorSpec.byId(id), history: history, forecast: forecast);
  }

  /// Agrega a série horária de PM2.5 em média diária.
  Map<DateTime, double> _dailyMean(List<dynamic> times, List<dynamic> values) {
    final sum = <DateTime, double>{};
    final count = <DateTime, int>{};
    for (var i = 0; i < times.length && i < values.length; i++) {
      final v = values[i];
      if (v is! num) continue;
      final day = dateOnly(DateTime.parse(times[i] as String));
      sum[day] = (sum[day] ?? 0) + v.toDouble();
      count[day] = (count[day] ?? 0) + 1;
    }
    return {for (final d in sum.keys) d: sum[d]! / count[d]!};
  }
}
