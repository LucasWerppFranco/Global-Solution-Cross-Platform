import 'dart:math';

import '../core/format.dart';
import 'models.dart';
import 'territory.dart';

/// Simula a API de concessionárias e serviços municipais, que não têm dados
/// abertos diários para a região. As séries são determinísticas por dia
/// (mesma semente), com tendência + sazonalidade semanal + ruído.
class SyntheticApi {
  static const _days = 30;

  /// base, crescimento no período (fração), amplitude semanal, ruído.
  static const _profiles = <String, (double, double, double, double)>{
    'agua': (880.0, 0.11, 25.0, 18.0),
    'energia': (3900.0, 0.06, 150.0, 60.0),
    'residuos': (470.0, 0.03, 45.0, 15.0),
    'ubs': (1120.0, 0.15, 20.0, 15.0),
    'zeladoria': (160.0, -0.06, 12.0, 8.0),
  };

  Future<List<Indicator>> fetch() async {
    // Latência de rede simulada, para exercitar o estado de carregamento.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final today = dateOnly(DateTime.now());
    return [
      for (final e in _profiles.entries)
        Indicator(spec: IndicatorSpec.byId(e.key), history: _series(e.key, e.value, today)),
    ];
  }

  List<DataPoint> _series(
      String id, (double, double, double, double) profile, DateTime today) {
    final (base, growth, weekly, noise) = profile;
    final seed = '$id${dateKey(today)}'
        .codeUnits
        .fold(7, (a, c) => (a * 31 + c) & 0x7fffffff);
    final rnd = Random(seed);
    final points = <DataPoint>[];
    for (var i = 0; i < _days; i++) {
      // Termina ontem: o dia de hoje ainda não foi "fechado" pela fonte.
      final date = DateTime(today.year, today.month, today.day - (_days - i));
      final value = base * (1 + growth * i / (_days - 1)) +
          weekly * sin(2 * pi * date.weekday / 7) +
          noise * (rnd.nextDouble() * 2 - 1);
      points.add(DataPoint(date, value));
    }
    return points;
  }
}
