import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Persistência local (funciona offline). Volume pequeno de dados → JSON em
/// SharedPreferences basta; leituras corrompidas são descartadas sem quebrar o app.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const _kConsent = 'consent_v1';
  static const _kSettings = 'settings_v1';
  static const _kOccurrences = 'occurrences_v1';
  static const _kDecisions = 'decisions_v1';
  static const _kSnapshot = 'snapshot_v1';

  T? _read<T>(String key, T Function(dynamic json) parse) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return parse(jsonDecode(raw));
    } catch (_) {
      return null; // dado antigo/corrompido: ignora em vez de travar
    }
  }

  Future<void> _write(String key, Object json) =>
      _prefs.setString(key, jsonEncode(json));

  bool get consent => _prefs.getBool(_kConsent) ?? false;
  Future<void> setConsent(bool v) => _prefs.setBool(_kConsent, v);

  Map<String, dynamic>? readSettings() =>
      _read(_kSettings, (j) => j as Map<String, dynamic>);
  Future<void> writeSettings(Map<String, dynamic> s) => _write(_kSettings, s);

  List<Occurrence> readOccurrences() =>
      _read(_kOccurrences, (j) => [
            for (final o in j as List) Occurrence.fromJson(o as Map<String, dynamic>)
          ]) ??
      [];
  Future<void> writeOccurrences(List<Occurrence> items) =>
      _write(_kOccurrences, [for (final o in items) o.toJson()]);

  Map<String, AlertDecision> readDecisions() =>
      _read(_kDecisions, (j) => {
            for (final e in (j as Map<String, dynamic>).entries)
              e.key: AlertDecision.fromJson(e.value as Map<String, dynamic>)
          }) ??
      {};
  Future<void> writeDecisions(Map<String, AlertDecision> d) =>
      _write(_kDecisions, {for (final e in d.entries) e.key: e.value.toJson()});

  TerritorySnapshot? readSnapshot() => _read(
      _kSnapshot, (j) => TerritorySnapshot.fromJson(j as Map<String, dynamic>));
  Future<void> writeSnapshot(TerritorySnapshot s) => _write(_kSnapshot, s.toJson());
}
