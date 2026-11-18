import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/widgets/alert_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../domain/alert_engine.dart';
import '../../state/decisions_state.dart';
import '../../state/territory_state.dart';

/// Lista de todos os alertas, com filtros (estado local da tela).
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final Set<Severity> _severities = {...Severity.values};
  bool _onlyPending = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Alertas preditivos')),
        body: TerritoryBody(builder: (context, snapshot) {
          final all = watchAlerts(context);
          final decisions = context.watch<DecisionsState>().decisions;
          final visible = all
              .where((a) => _severities.contains(a.severity))
              .where((a) => !_onlyPending || !decisions.containsKey(a.id))
              .toList();

          return ListView(
            padding: AppSpacing.page,
            children: [
              FreshnessBanner(snapshot: snapshot),
              const HumanDecisionBanner(compact: true),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final s in Severity.values.reversed)
                    FilterChip(
                      label: Text(
                          '${s.label} (${all.where((a) => a.severity == s).length})'),
                      selected: _severities.contains(s),
                      onSelected: (on) => setState(
                          () => on ? _severities.add(s) : _severities.remove(s)),
                    ),
                  FilterChip(
                    label: const Text('Só pendentes de avaliação'),
                    selected: _onlyPending,
                    onSelected: (on) => setState(() => _onlyPending = on),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (all.isEmpty)
                const EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'Nenhum alerta ativo',
                  message: 'Todos os indicadores estão dentro dos limiares configurados. '
                      'Ajuste os limiares em Ajustes › Limiares de alerta.',
                )
              else if (visible.isEmpty)
                const EmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'Nenhum alerta com estes filtros',
                  message: 'Altere os filtros acima para ver outros alertas.',
                )
              else
                for (final a in visible) AlertTile(alert: a, decision: decisions[a.id]),
            ],
          );
        }),
      );
}
