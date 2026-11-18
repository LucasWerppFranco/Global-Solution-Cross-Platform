import 'package:flutter/material.dart';

import '../data/local_store.dart';
import '../data/territory.dart';

/// Estado global de preferências: tema, acessibilidade, limiares e consentimento.
class SettingsState extends ChangeNotifier {
  SettingsState(this._store) : hasConsent = _store.consent {
    final j = _store.readSettings();
    if (j == null) return;
    try {
      themeMode = ThemeMode.values.asNameMap()[j['themeMode']] ?? ThemeMode.system;
      highContrast = j['highContrast'] == true;
      fontScale = ((j['fontScale'] as num?) ?? 1.0).clamp(minFontScale, maxFontScale).toDouble();
      simulateOffline = j['simulateOffline'] == true;
      final saved = j['thresholds'] as Map<String, dynamic>? ?? {};
      thresholds = {
        ...IndicatorSpec.defaultThresholds,
        for (final e in saved.entries)
          if (e.value is num && IndicatorSpec.tryById(e.key) != null)
            e.key: (e.value as num).toDouble(),
      };
    } catch (_) {
      // Preferências corrompidas: mantém os padrões.
    }
  }

  final LocalStore _store;

  static const minFontScale = 1.0;
  static const maxFontScale = 2.0;

  bool hasConsent;
  ThemeMode themeMode = ThemeMode.system;
  bool highContrast = false;
  double fontScale = 1.0;
  bool simulateOffline = false;
  Map<String, double> thresholds = IndicatorSpec.defaultThresholds;

  double thresholdFor(String id) =>
      thresholds[id] ?? IndicatorSpec.byId(id).defaultThreshold;

  Future<void> _save() {
    notifyListeners();
    return _store.writeSettings({
      'themeMode': themeMode.name,
      'highContrast': highContrast,
      'fontScale': fontScale,
      'simulateOffline': simulateOffline,
      'thresholds': thresholds,
    });
  }

  Future<void> setThemeMode(ThemeMode v) {
    themeMode = v;
    return _save();
  }

  Future<void> setHighContrast(bool v) {
    highContrast = v;
    return _save();
  }

  Future<void> setFontScale(double v) {
    fontScale = v;
    return _save();
  }

  Future<void> setSimulateOffline(bool v) {
    simulateOffline = v;
    return _save();
  }

  /// Substitui o mapa (nova identidade) para que os alertas sejam recalculados.
  Future<void> setThresholds(Map<String, double> v) {
    thresholds = {...IndicatorSpec.defaultThresholds, ...v};
    return _save();
  }

  Future<void> setConsent(bool v) async {
    hasConsent = v;
    notifyListeners();
    await _store.setConsent(v);
  }
}
