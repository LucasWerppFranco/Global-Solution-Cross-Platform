import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/widgets/state_views.dart';
import '../../state/decisions_state.dart';
import '../../state/occurrences_state.dart';
import '../../state/settings_state.dart';
import '../../state/territory_state.dart';

/// Ajustes: aparência/acessibilidade, alertas, dados e privacidade.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmErase(BuildContext context) async {
    final settings = context.read<SettingsState>();
    final occurrences = context.read<OccurrencesState>();
    final decisions = context.read<DecisionsState>();
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar meus dados?'),
        content: const Text(
          'Isso remove do aparelho suas ocorrências, avaliações de alertas e o '
          'consentimento. Os dados públicos do território continuam disponíveis.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Apagar')),
        ],
      ),
    );
    if (ok != true) return;
    await occurrences.clear();
    await decisions.clear();
    await settings.setConsent(false);
    navigator.pushNamedAndRemoveUntil(Routes.consent, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsState>();
    final territory = context.read<TerritoryState>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          const SectionTitle('Aparência e acessibilidade'),
          Text('Tema', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto),
                  label: Text('Sistema')),
              ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode),
                  label: Text('Claro')),
              ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode),
                  label: Text('Escuro')),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) => s.setThemeMode(v.first),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.contrast),
            title: const Text('Alto contraste'),
            subtitle: const Text('Cores e bordas reforçadas para baixa visão.'),
            value: s.highContrast,
            onChanged: s.setHighContrast,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.format_size),
            title: const Text('Tamanho do texto'),
            subtitle: Text('${(s.fontScale * 100).round()}% (soma-se ao ajuste do sistema)'),
          ),
          Slider(
            value: s.fontScale,
            min: SettingsState.minFontScale,
            max: SettingsState.maxFontScale,
            divisions: 4,
            label: '${(s.fontScale * 100).round()}%',
            semanticFormatterCallback: (v) => 'Tamanho do texto ${(v * 100).round()} por cento',
            onChanged: s.setFontScale,
          ),
          const SectionTitle('Alertas'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune),
            title: const Text('Limiares de alerta'),
            subtitle: const Text('Defina a partir de que valor cada indicador gera alerta.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, Routes.thresholds),
          ),
          const SectionTitle('Dados'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.cloud_off),
            title: const Text('Simular falta de conexão'),
            subtitle: const Text(
                'Para demonstração: força o uso do cache local (ou o estado de erro, '
                'se ainda não houver cache).'),
            value: s.simulateOffline,
            onChanged: (v) async {
              await s.setSimulateOffline(v);
              await territory.load();
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.refresh),
            title: const Text('Atualizar dados agora'),
            onTap: territory.load,
          ),
          const SectionTitle('Privacidade'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: const Text('Ver termo de consentimento'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, Routes.consent, arguments: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_forever, color: theme.colorScheme.error),
            title: const Text('Apagar meus dados deste aparelho'),
            onTap: () => _confirmErase(context),
          ),
          const SectionTitle('Sobre'),
          const Text(
            'Território Vivo · FIAP Global Solution 2026.2 — Territory Predictive Insights. '
            'Clima e qualidade do ar: Open-Meteo (CC BY 4.0). Recursos e serviços: '
            'dados sintéticos para demonstração.',
          ),
        ],
      ),
    );
  }
}
