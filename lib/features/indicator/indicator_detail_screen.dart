import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/widgets/alert_widgets.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/kpi_card.dart';
import '../../core/widgets/state_views.dart';
import '../../domain/alert_engine.dart';
import '../../state/decisions_state.dart';
import '../../state/settings_state.dart';
import '../../state/territory_state.dart';

/// Detalhe do indicador: histórico de 30 dias, previsão/projeção, estatísticas,
/// fonte e alertas relacionados.
class IndicatorDetailScreen extends StatelessWidget {
  const IndicatorDetailScreen({super.key, required this.indicatorId});
  final String indicatorId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Detalhe do indicador')),
        body: TerritoryBody(builder: (context, snapshot) {
          final ind = snapshot.indicator(indicatorId);
          if (ind == null) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'Indicador indisponível',
              message: 'A fonte de dados não retornou este indicador.',
            );
          }
          final theme = Theme.of(context);
          final spec = ind.spec;
          final threshold = context.watch<SettingsState>().thresholdFor(ind.id);
          final decisions = context.watch<DecisionsState>().decisions;
          final alerts =
              watchAlerts(context).where((a) => a.spec.id == ind.id).toList();
          final values = [for (final p in ind.history) p.value];
          final stats = describe(values);
          final trend = linearTrend(
              values.sublist(values.length > AlertEngine.trendWindow
                  ? values.length - AlertEngine.trendWindow
                  : 0));
          final official = ind.forecast.isNotEmpty;
          final projection = official ? ind.forecast : projectLinear(ind.history);
          String v(double x) => '${fmtNum(x, spec.decimals)} ${spec.unit}';
          final last = projection.last;

          return ListView(
            padding: AppSpacing.page,
            children: [
              FreshnessBanner(snapshot: snapshot),
              Row(
                children: [
                  Icon(spec.icon, size: 32, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(spec.name, style: theme.textTheme.headlineSmall),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  Chip(
                    avatar: Icon(spec.synthetic ? Icons.science_outlined : Icons.public,
                        size: 18),
                    label: Text(spec.synthetic ? 'Dado sintético' : 'Dado real'),
                  ),
                  Chip(label: Text(spec.panel.label)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Último valor (${fmtDate(ind.history.last.date)})',
                  style: theme.textTheme.labelLarge),
              Text(v(ind.current), style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.md),
              TrendChart(
                history: ind.history,
                projection: projection,
                threshold: threshold,
                height: 220,
                decimals: spec.decimals,
                semanticLabel: 'Gráfico de ${spec.name} nos últimos '
                    '${ind.history.length} dias: de ${v(ind.history.first.value)} '
                    'a ${v(ind.current)}. '
                    '${official ? 'Previsão oficial' : 'Projeção linear'} chega a '
                    '${v(last.value)} em ${fmtDate(last.date)}. Limiar: ${v(threshold)}.',
              ),
              const SizedBox(height: AppSpacing.sm),
              ChartLegend(
                  projectionLabel:
                      official ? 'Previsão oficial' : 'Projeção linear (7 dias)'),
              const SectionTitle('Estatísticas'),
              ResponsiveGrid(
                minItemWidth: 150,
                children: [
                  StatTile(label: 'Média (${values.length} dias)', value: v(stats.mean)),
                  StatTile(label: 'Mínimo', value: v(stats.min)),
                  StatTile(label: 'Máximo', value: v(stats.max)),
                  StatTile(
                      label: 'Desvio-padrão',
                      value: fmtNum(stats.std, spec.decimals + 1)),
                  StatTile(
                      label: 'Tendência (14 dias)',
                      value: '${fmtSigned(trend.slope, spec.decimals + 1)}/dia'),
                  StatTile(label: 'R² da tendência', value: fmtNum(trend.r2, 2)),
                ],
              ),
              const SectionTitle('Sobre os dados'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: BulletList([
                    'Fonte: ${spec.source}.',
                    'Limiar atual: ${v(threshold)} (ajustável pelo gestor).',
                    'Limitação: ${spec.limitation}',
                    'Público mais afetado: ${spec.beneficiariesNote}.',
                  ]),
                ),
              ),
              const SectionTitle('Alertas relacionados'),
              if (alerts.isEmpty)
                const EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'Sem alertas para este indicador',
                  message: 'Valor atual, previsão e tendência estão abaixo do limiar.',
                )
              else
                for (final a in alerts) AlertTile(alert: a, decision: decisions[a.id]),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, Routes.thresholds),
                icon: const Icon(Icons.tune),
                label: const Text('Ajustar limiares de alerta'),
              ),
            ],
          );
        }),
      );
}
