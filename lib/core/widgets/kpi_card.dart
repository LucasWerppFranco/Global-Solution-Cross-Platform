import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../format.dart';
import '../routes.dart';
import '../theme.dart';
import 'charts.dart';

/// Card de indicador: valor atual, variação semanal, mini-gráfico e limiar.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.indicator,
    required this.threshold,
    this.hasAlert = false,
  });

  final Indicator indicator;
  final double threshold;
  final bool hasAlert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final spec = indicator.spec;
    final change = indicator.weeklyChange;
    final value = '${fmtNum(indicator.current, spec.decimals)} ${spec.unit}';
    final trendText =
        change == null ? 'sem base semanal' : '${fmtSigned(change, 1)}% em 7 dias';
    final above = indicator.current >= threshold;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, Routes.indicator,
            arguments: indicator.id),
        child: Semantics(
          button: true,
          label: '${spec.name}: $value, $trendText. '
              '${above ? 'Acima' : 'Dentro'} do limiar de '
              '${fmtNum(threshold, spec.decimals)} ${spec.unit}. '
              '${hasAlert ? 'Há alerta ativo. ' : ''}Toque para ver o histórico.',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(spec.icon, color: scheme.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(spec.name, style: theme.textTheme.titleSmall)),
                    if (hasAlert)
                      Icon(Icons.warning_amber_rounded, color: scheme.error),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(value, style: theme.textTheme.headlineSmall),
                Row(
                  children: [
                    Icon(
                      (change ?? 0) >= 0 ? Icons.trending_up : Icons.trending_down,
                      size: 18,
                      color: (change ?? 0) > 0 ? scheme.error : scheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: Text(trendText)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                TrendChart(
                  history: indicator.history,
                  threshold: threshold,
                  compact: true,
                  height: 48,
                  semanticLabel: '',
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Limiar: ${fmtNum(threshold, spec.decimals)} ${spec.unit}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: above ? scheme.error : scheme.onSurfaceVariant,
                    fontWeight: above ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pequeno bloco "rótulo + valor" para estatísticas.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(value, style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
