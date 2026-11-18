import 'package:flutter/foundation.dart';

import '../data/local_store.dart';
import '../data/models.dart';

/// Ocorrências registradas por cidadãos (persistidas localmente).
class OccurrencesState extends ChangeNotifier {
  OccurrencesState(LocalStore store)
      : _store = store,
        _items = store.readOccurrences();

  final LocalStore _store;
  List<Occurrence> _items;

  List<Occurrence> get items => List.unmodifiable(_items);

  Future<void> add(Occurrence o) => _set([o, ..._items]);

  Future<void> remove(String id) =>
      _set(_items.where((o) => o.id != id).toList());

  Future<void> clear() => _set([]);

  Future<void> _set(List<Occurrence> items) {
    _items = items;
    notifyListeners();
    return _store.writeOccurrences(items);
  }
}
