import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/widgets/alert_widgets.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/kpi_card.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models.dart';
import '../../domain/alert_engine.dart';
import '../../state/decisions_state.dart';
import '../../state/occurrences_state.dart';
import '../../state/settings_state.dart';
import '../../state/territory_state.dart';

/// Dashboard de um painel (clima, recursos ou serviços): KPIs com histórico e
/// tendência, uma seção de destaque própria do tema e os alertas do painel.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.panel});
  final Panel panel;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Painel · ${panel.label}')),
        body: TerritoryBody(builder: (context, snapshot) {
          final settings = context.watch<SettingsState>();
          final decisions = context.watch<DecisionsState>().decisions;
          final indicators = snapshot.byPanel(panel);
          final alerts =
              watchAlerts(context).where((a) => a.spec.panel == panel).toList();

          if (indicators.isEmpty) {
            return EmptyState(
              icon: panel.icon,
              title: 'Sem dados para este painel',
              message: 'A fonte não retornou indicadores. Atualize na Visão geral.',
            );
          }
          return ListView(
            padding: AppSpacing.page,
            children: [
              FreshnessBanner(snapshot: snapshot),
              Text(panel.description),
              const SectionTitle('Indicadores'),
              ResponsiveGrid(children: [
                for (final i in indicators)
                  KpiCard(
                    indicator: i,
                    threshold: settings.thresholdFor(i.id),
                    hasAlert: alerts.any((a) => a.spec.id == i.id),
                  ),
              ]),
              switch (panel) {
                Panel.clima => _ClimaHighlights(indicators: indicators),
                Panel.recursos =>
                  _RecursosHighlights(indicators: indicators, settings: settings),
                Panel.servicos => const _ServicosHighlights(),
              },
              const SectionTitle('Alertas deste painel'),
              if (alerts.isEmpty)
                const EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'Nenhum alerta neste painel',
                  message: 'Os indicadores estão dentro dos limiares e sem tendência de risco.',
                )
              else
                for (final a in alerts) AlertTile(alert: a, decision: decisions[a.id]),
            ],
          );
        }),
      );
}

/// Clima: previsão oficial dos próximos dias (temperatura e chuva).
class _ClimaHighlights extends StatelessWidget {
  const _ClimaHighlights({required this.indicators});
  final List<Indicator> indicators;

  @override
  Widget build(BuildContext context) {
    final temp = indicators.where((i) => i.id == 'temp_max').firstOrNull;
    final rain = indicators.where((i) => i.id == 'precip').firstOrNull;
    final days = temp?.forecast ?? const <DataPoint>[];
    if (days.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Previsão para os próximos dias'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final d in days)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Builder(builder: (context) {
                    final mm = rain?.forecast
                        .where((p) => p.date == d.date)
                        .firstOrNull
                        ?.value;
                    final label = '${fmtWeekday(d.date)} ${fmtDate(d.date)}: '
                        'máxima ${fmtNum(d.value)} °C'
                        '${mm == null ? '' : ', chuva ${fmtNum(mm)} mm'}';
                    return Semantics(
                      label: label,
                      excludeSemantics: true,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            children: [
                              Text(fmtWeekday(d.date), style: theme.textTheme.labelLarge),
                              Text(fmtDate(d.date), style: theme.textTheme.labelSmall),
                              const SizedBox(height: AppSpacing.sm),
                              Text('${fmtNum(d.value, 0)}°',
                                  style: theme.textTheme.titleLarge),
                              if (mm != null) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.water_drop_outlined, size: 16),
                                    Text('${fmtNum(mm)} mm'),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Recursos: consumo atual em relação ao limiar e projeção de 7 dias.
class _RecursosHighlights extends StatelessWidget {
  const _RecursosHighlights({required this.indicators, required this.settings});
  final List<Indicator> indicators;
  final SettingsState settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Consumo em relação ao limiar'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                for (final i in indicators)
                  Builder(builder: (context) {
                    final t = settings.thresholdFor(i.id);
                    final ratio = i.current / t;
                    final projected = projectLinear(i.history).last.value;
                    final u = i.spec.unit;
                    final d = i.spec.decimals;
                    final text = '${(ratio * 100).round()}% do limiar · '
                        'projeção em 7 dias: ${fmtNum(projected, d)} $u';
                    return Semantics(
                      label: '${i.spec.name}: $text',
                      excludeSemantics: true,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i.spec.name, style: theme.textTheme.titleSmall),
                            const SizedBox(height: AppSpacing.xs),
                            LinearProgressIndicator(
                              value: ratio.clamp(0.0, 1.0).toDouble(),
                              minHeight: 12,
                              borderRadius: BorderRadius.circular(6),
                              color: ratio >= 1 ? theme.colorScheme.error : null,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(text),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Serviços: ocorrências cidadãs registradas no app, por categoria.
class _ServicosHighlights extends StatelessWidget {
  const _ServicosHighlights();

  @override
  Widget build(BuildContext context) {
    final items = context.watch<OccurrencesState>().items;
    final counts = {
      for (final c in OccurrenceCategory.values)
        c: items.where((o) => o.category == c).length,
    }..removeWhere((_, n) => n == 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Ocorrências cidadãs por categoria'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: counts.isEmpty
                ? EmptyState(
                    icon: Icons.report_outlined,
                    title: 'Nenhuma ocorrência registrada',
                    message: 'Registros de cidadãos aparecem aqui e ajudam a '
                        'validar os alertas com a percepção de quem vive no território.',
                    action: FilledButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, Routes.occurrenceForm),
                      icon: const Icon(Icons.add),
                      label: const Text('Registrar ocorrência'),
                    ),
                  )
                : HorizontalBars(items: [
                    for (final e in counts.entries) (e.key.label, e.value.toDouble()),
                  ]),
          ),
        ),
      ],
    );
  }
}
