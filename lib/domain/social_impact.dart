import 'dart:math' as math;

import '../data/models.dart';
import '../data/territory.dart';
import 'alert_engine.dart';

/// Indicador de benefício social: relaciona o desempenho analítico
/// (alertas gerados e avaliados por humanos) a pessoas potencialmente beneficiadas.
class SocialImpact {
  const SocialImpact({
    required this.peopleBenefited,
    required this.decided,
    required this.total,
  });

  /// Soma dos públicos dos indicadores com alerta marcado como "revisado"
  /// (cada indicador conta uma vez; limitado à população do território).
  final int peopleBenefited;
  final int decided;
  final int total;

  /// Fração dos alertas ativos que já passaram por avaliação humana.
  double get supervisionRate => total == 0 ? 1 : decided / total;

  static SocialImpact compute(
      List<Alert> alerts, Map<String, AlertDecision> decisions) {
    final reviewed = {
      for (final a in alerts)
        if (decisions[a.id]?.status == DecisionStatus.revisado) a.spec,
    };
    final people = reviewed.fold(0, (sum, s) => sum + s.beneficiaries);
    return SocialImpact(
      peopleBenefited: math.min(people, Territory.population),
      decided: alerts.where((a) => decisions.containsKey(a.id)).length,
      total: alerts.length,
    );
  }
}
