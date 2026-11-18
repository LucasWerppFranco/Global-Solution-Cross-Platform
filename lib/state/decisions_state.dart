import 'package:flutter/foundation.dart';

import '../data/local_store.dart';
import '../data/models.dart';

/// Avaliações humanas dos alertas (revisado/descartado), com nota opcional.
/// É só registro para transparência: nada é executado automaticamente.
class DecisionsState extends ChangeNotifier {
  DecisionsState(LocalStore store)
      : _store = store,
        _decisions = store.readDecisions();

  final LocalStore _store;
  Map<String, AlertDecision> _decisions;

  Map<String, AlertDecision> get decisions => Map.unmodifiable(_decisions);

  Future<void> decide(String alertId, DecisionStatus status, String note) =>
      _set({
        ..._decisions,
        alertId: AlertDecision(
            status: status, note: note.trim(), decidedAt: DateTime.now()),
      });

  Future<void> undo(String alertId) =>
      _set({..._decisions}..remove(alertId));

  Future<void> clear() => _set({});

  Future<void> _set(Map<String, AlertDecision> d) {
    _decisions = d;
    notifyListeners();
    return _store.writeDecisions(d);
  }
}
