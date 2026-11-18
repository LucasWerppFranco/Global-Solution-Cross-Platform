import 'dart:math';

import 'package:flutter/material.dart' show IconData, Icons;

import 'territory.dart';

/// Os três dashboards do app.
enum Panel {
  clima('Clima local', Icons.thermostat,
      'Temperatura, chuva e qualidade do ar — dados reais da Open-Meteo.'),
  recursos('Recursos', Icons.water_drop_outlined,
      'Consumo de água, energia e geração de resíduos — dados sintéticos.'),
  servicos('Serviços', Icons.local_hospital_outlined,
      'Demanda por saúde, zeladoria e ocorrências registradas por cidadãos.');

  const Panel(this.label, this.icon, this.description);
  final String label;
  final IconData icon;
  final String description;
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DataPoint {
  const DataPoint(this.date, this.value);
  final DateTime date;
  final double value;

  List<Object> toJson() => [date.toIso8601String(), value];
  factory DataPoint.fromJson(List<dynamic> j) =>
      DataPoint(DateTime.parse(j[0] as String), (j[1] as num).toDouble());
}

/// Série de um indicador. [history] nunca é vazio; [forecast] só existe
/// quando a fonte fornece previsão oficial (clima).
class Indicator {
  const Indicator({
    required this.spec,
    required this.history,
    this.forecast = const [],
  });

  final IndicatorSpec spec;
  final List<DataPoint> history;
  final List<DataPoint> forecast;

  String get id => spec.id;
  double get current => history.last.value;

  /// Variação percentual em relação a 7 dias antes.
  double? get weeklyChange {
    if (history.length < 8) return null;
    final before = history[history.length - 8].value;
    if (before == 0) return null;
    return (current - before) / before * 100;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'history': [for (final p in history) p.toJson()],
        'forecast': [for (final p in forecast) p.toJson()],
      };

  factory Indicator.fromJson(Map<String, dynamic> j) => Indicator(
        spec: IndicatorSpec.byId(j['id'] as String),
        history: [
          for (final p in j['history'] as List) DataPoint.fromJson(p as List)
        ],
        forecast: [
          for (final p in j['forecast'] as List) DataPoint.fromJson(p as List)
        ],
      );
}

/// Resultado de uma carga de dados (da rede ou do cache local).
class TerritorySnapshot {
  const TerritorySnapshot({
    required this.indicators,
    required this.fetchedAt,
    this.fromCache = false,
  });

  final List<Indicator> indicators;
  final DateTime fetchedAt;
  final bool fromCache;

  Indicator? indicator(String id) =>
      indicators.where((i) => i.id == id).firstOrNull;

  List<Indicator> byPanel(Panel p) =>
      indicators.where((i) => i.spec.panel == p).toList();

  TerritorySnapshot asCached() => TerritorySnapshot(
      indicators: indicators, fetchedAt: fetchedAt, fromCache: true);

  Map<String, dynamic> toJson() => {
        'fetchedAt': fetchedAt.toIso8601String(),
        'indicators': [for (final i in indicators) i.toJson()],
      };

  factory TerritorySnapshot.fromJson(Map<String, dynamic> j) =>
      TerritorySnapshot(
        fetchedAt: DateTime.parse(j['fetchedAt'] as String),
        indicators: [
          for (final i in j['indicators'] as List)
            Indicator.fromJson(i as Map<String, dynamic>)
        ],
      );
}

enum OccurrenceCategory {
  alagamento('Alagamento', Icons.water),
  lixo('Descarte irregular de lixo', Icons.delete_outline),
  iluminacao('Iluminação pública', Icons.lightbulb_outline),
  via('Buraco ou calçada danificada', Icons.construction),
  saude('Fila ou falta de atendimento em saúde', Icons.local_hospital_outlined),
  outro('Outro', Icons.more_horiz);

  const OccurrenceCategory(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Ocorrência registrada por cidadão. Anônima por construção: não há campos
/// de nome, contato ou coordenadas — apenas um código aleatório e o distrito.
class Occurrence {
  const Occurrence({
    required this.id,
    required this.category,
    required this.district,
    required this.description,
    required this.date,
    required this.createdAt,
  });

  final String id;
  final OccurrenceCategory category;
  final String district;
  final String description;
  final DateTime date;
  final DateTime createdAt;

  String get shortId => id.substring(0, 6).toUpperCase();

  static String newAnonymousId() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
        'district': district,
        'description': description,
        'date': date.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Occurrence.fromJson(Map<String, dynamic> j) => Occurrence(
        id: j['id'] as String,
        category: OccurrenceCategory.values.byName(j['category'] as String),
        district: j['district'] as String,
        description: j['description'] as String,
        date: DateTime.parse(j['date'] as String),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

enum DecisionStatus {
  revisado('Revisado pelo gestor'),
  descartado('Descartado pelo gestor');

  const DecisionStatus(this.label);
  final String label;
}

/// Registro da avaliação humana de um alerta. Não dispara nenhuma ação.
class AlertDecision {
  const AlertDecision({
    required this.status,
    required this.note,
    required this.decidedAt,
  });

  final DecisionStatus status;
  final String note;
  final DateTime decidedAt;

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'note': note,
        'decidedAt': decidedAt.toIso8601String(),
      };

  factory AlertDecision.fromJson(Map<String, dynamic> j) => AlertDecision(
        status: DecisionStatus.values.byName(j['status'] as String),
        note: j['note'] as String? ?? '',
        decidedAt: DateTime.parse(j['decidedAt'] as String),
      );
}
