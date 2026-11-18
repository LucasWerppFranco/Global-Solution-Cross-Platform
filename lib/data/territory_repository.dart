import 'local_store.dart';
import 'models.dart';
import 'open_meteo_api.dart';
import 'synthetic_api.dart';

/// Combina as fontes (real + sintética) e garante uso offline:
/// rede OK → salva no cache; rede falhou → devolve o último cache.
class TerritoryRepository {
  TerritoryRepository({
    required LocalStore store,
    required bool Function() simulateOffline,
    OpenMeteoApi? meteo,
    SyntheticApi? synthetic,
  })  : _store = store,
        _simulateOffline = simulateOffline,
        _meteo = meteo ?? OpenMeteoApi(),
        _synthetic = synthetic ?? SyntheticApi();

  final LocalStore _store;
  final bool Function() _simulateOffline;
  final OpenMeteoApi _meteo;
  final SyntheticApi _synthetic;

  Future<TerritorySnapshot> load() async {
    try {
      if (_simulateOffline()) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        throw const ApiException('Modo offline simulado (Ajustes › Dados).');
      }
      final results = await Future.wait([_meteo.fetch(), _synthetic.fetch()]);
      final snapshot = TerritorySnapshot(
        indicators: [...results[0], ...results[1]],
        fetchedAt: DateTime.now(),
      );
      await _store.writeSnapshot(snapshot);
      return snapshot;
    } catch (_) {
      final cached = _store.readSnapshot();
      if (cached != null) return cached.asCached();
      rethrow;
    }
  }
}
