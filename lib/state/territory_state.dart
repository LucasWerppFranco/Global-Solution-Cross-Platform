import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/territory_repository.dart';
import '../domain/alert_engine.dart';
import 'settings_state.dart';

enum LoadStatus { loading, ready, error }

/// Estado global dos dados do território (carregamento, erro, dados).
class TerritoryState extends ChangeNotifier {
  TerritoryState(this._repo);

  final TerritoryRepository _repo;

  LoadStatus status = LoadStatus.loading;
  TerritorySnapshot? snapshot;
  String? error;
  bool refreshing = false;

  /// Primeira carga mostra tela de carregamento; atualizações mantêm os dados
  /// na tela (pull-to-refresh) e apenas sinalizam [refreshing].
  Future<void> load() async {
    if (refreshing) return;
    refreshing = true;
    error = null;
    if (snapshot == null && status != LoadStatus.loading) {
      status = LoadStatus.loading;
      notifyListeners();
    }
    try {
      snapshot = await _repo.load();
      status = LoadStatus.ready;
    } catch (e) {
      error = 'Não foi possível carregar os dados do território e não há '
          'dados salvos neste aparelho. Verifique a conexão e tente novamente.\n($e)';
      if (snapshot == null) status = LoadStatus.error;
    }
    refreshing = false;
    notifyListeners();
  }
}

/// Alertas derivados do estado global (dados + limiares). Recalculados a cada
/// mudança — o motor é puro e barato (8 séries de ~30 pontos).
List<Alert> watchAlerts(BuildContext context) {
  final snapshot = context.watch<TerritoryState>().snapshot;
  final thresholds =
      context.select<SettingsState, Map<String, double>>((s) => s.thresholds);
  if (snapshot == null) return const [];
  return AlertEngine.generate(
    indicators: snapshot.indicators,
    thresholds: thresholds,
    generatedAt: snapshot.fetchedAt,
    fromCache: snapshot.fromCache,
  );
}
