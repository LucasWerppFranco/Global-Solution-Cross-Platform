import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/widgets/alert_widgets.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models.dart';
import '../../data/territory.dart';
import '../../domain/alert_engine.dart';
import '../../domain/social_impact.dart';
import '../../state/decisions_state.dart';
import '../../state/territory_state.dart';

/// Visão geral: impacto social, acesso aos 3 painéis e alertas prioritários.
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final territory = context.watch<TerritoryState>();
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Território Vivo'),
            Text(Territory.shortName, style: TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar dados',
            onPressed: territory.refreshing ? null : territory.load,
            icon: territory.refreshing
                ? const SizedBox.square(
                    dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: TerritoryBody(builder: (context, snapshot) {
        final alerts = watchAlerts(context);
        final decisions = context.watch<DecisionsState>().decisions;
        final impact = SocialImpact.compute(alerts, decisions);
        return RefreshIndicator(
          onRefresh: territory.load,
          child: ListView(
            padding: AppSpacing.page,
            children: [
              FreshnessBanner(snapshot: snapshot),
              const HumanDecisionBanner(compact: true),
              const SizedBox(height: AppSpacing.md),
              _SocialImpactCard(impact: impact),
              const SectionTitle('Painéis do território'),
              ResponsiveGrid(
                minItemWidth: 260,
                children: [
                  for (final p in Panel.values)
                    _PanelCard(
                      panel: p,
                      alertCount: alerts.where((a) => a.spec.panel == p).length,
                      indicatorCount: snapshot.byPanel(p).length,
                    ),
                ],
              ),
              const SectionTitle('Alertas prioritários'),
              if (alerts.isEmpty)
                const EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'Nenhum alerta ativo',
                  message: 'Todos os indicadores estão dentro dos limiares configurados.',
                )
              else
                for (final a in alerts.take(3))
                  AlertTile(alert: a, decision: decisions[a.id]),
            ],
          ),
        );
      }),
    );
  }
}

class _SocialImpactCard extends StatelessWidget {
  const _SocialImpactCard({required this.impact});
  final SocialImpact impact;

  void _explain(BuildContext context) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Como calculamos o impacto'),
          content: SingleChildScrollView(
            child: Text(
              'Cada indicador tem um público estimado que se beneficia quando um '
              'alerta é avaliado a tempo (ex.: idosos no calor extremo, moradores de '
              'áreas de alagamento). Somamos o público dos indicadores com alerta '
              'marcado como "revisado" por um gestor — cada indicador conta uma vez, '
              'limitado à população do território (${fmtInt(Territory.population)} hab.).\n\n'
              'É uma estimativa de alcance potencial, não uma medição de resultado.',
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context), child: const Text('Entendi')),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.volunteer_activism, color: scheme.onPrimaryContainer),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Benefício social',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: scheme.onPrimaryContainer)),
                ),
                IconButton(
                  tooltip: 'Como este indicador é calculado',
                  onPressed: () => _explain(context),
                  icon: Icon(Icons.info_outline, color: scheme.onPrimaryContainer),
                ),
              ],
            ),
            // O número "sobe" quando um alerta é revisado: mostra o efeito
            // da decisão humana no indicador social.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: impact.peopleBenefited.toDouble()),
              duration: AppMotion.of(context),
              curve: Curves.easeOutCubic,
              builder: (context, v, child) => Text(
                fmtInt(v.round()),
                style: theme.textTheme.headlineMedium
                    ?.copyWith(color: scheme.onPrimaryContainer),
              ),
            ),
            Text(
              'moradores potencialmente beneficiados por alertas revisados por gestores',
              style: TextStyle(color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              label: 'Supervisão humana: ${impact.decided} de ${impact.total} alertas avaliados',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedBar(value: impact.supervisionRate, minHeight: 8),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Supervisão humana: ${impact.decided} de ${impact.total} alertas avaliados',
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.panel,
    required this.alertCount,
    required this.indicatorCount,
  });

  final Panel panel;
  final int alertCount;
  final int indicatorCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alertText = switch (alertCount) {
      0 => 'Sem alertas',
      1 => '1 alerta ativo',
      _ => '$alertCount alertas ativos',
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, Routes.dashboard, arguments: panel),
        child: Semantics(
          button: true,
          label: 'Painel ${panel.label}. $indicatorCount indicadores. $alertText. '
              'Toque para abrir.',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(panel.icon, color: theme.colorScheme.primary, size: 28),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(panel.label, style: theme.textTheme.titleMedium)),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(panel.description),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      alertCount > 0 ? Severity.atencao.icon : Icons.check_circle_outline,
                      size: 18,
                      color: alertCount > 0
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: Text('$indicatorCount indicadores · $alertText')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
