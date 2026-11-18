import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/widgets/alert_widgets.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models.dart';
import '../../domain/alert_engine.dart';
import '../../state/decisions_state.dart';
import '../../state/settings_state.dart';
import '../../state/territory_state.dart';

/// Detalhe do alerta: justificativa (evidências), confiança, limitações,
/// sugestão e registro da decisão humana.
class AlertDetailScreen extends StatelessWidget {
  const AlertDetailScreen({super.key, required this.alertId});
  final String alertId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Detalhe do alerta')),
        body: TerritoryBody(builder: (context, snapshot) {
          final alert =
              watchAlerts(context).where((a) => a.id == alertId).firstOrNull;
          if (alert == null) {
            return const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'Alerta não está mais ativo',
              message: 'Os dados ou os limiares mudaram e esta condição não se aplica mais.',
            );
          }
          final theme = Theme.of(context);
          final indicator = snapshot.indicator(alert.spec.id);
          final threshold = context.watch<SettingsState>().thresholdFor(alert.spec.id);
          final decision = context.watch<DecisionsState>().decisions[alert.id];

          return ListView(
            padding: AppSpacing.page,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  SeverityChip(alert.severity),
                  Chip(label: Text(alert.kind.label)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                header: true,
                child: Text(alert.title, style: theme.textTheme.headlineSmall),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(alert.summary, style: theme.textTheme.bodyLarge),
              const SizedBox(height: AppSpacing.md),
              const HumanDecisionBanner(),
              _Section(
                icon: Icons.fact_check_outlined,
                title: 'Justificativa (evidências)',
                child: BulletList(alert.evidence),
              ),
              if (indicator != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        TrendChart(
                          history: indicator.history,
                          projection: indicator.forecast.isNotEmpty
                              ? indicator.forecast
                              : projectLinear(indicator.history),
                          threshold: threshold,
                          decimals: alert.spec.decimals,
                          semanticLabel: 'Gráfico de ${alert.spec.name} com histórico, '
                              'projeção e limiar de ${fmtNum(threshold, alert.spec.decimals)} '
                              '${alert.spec.unit}.',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ChartLegend(
                          projectionLabel: indicator.forecast.isNotEmpty
                              ? 'Previsão oficial'
                              : 'Projeção linear',
                        ),
                      ],
                    ),
                  ),
                ),
              _Section(
                icon: Icons.speed,
                title: 'Nível de confiança',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConfidenceBadge(alert: alert),
                    const SizedBox(height: AppSpacing.sm),
                    LinearProgressIndicator(
                      value: alert.confidenceScore,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(alert.confidenceRationale),
                  ],
                ),
              ),
              _Section(
                icon: Icons.report_problem_outlined,
                title: 'Limitações — quando não confiar',
                child: BulletList(alert.limitations, icon: Icons.remove),
              ),
              _Section(
                icon: Icons.lightbulb_outline,
                title: 'Sugestão para avaliação do gestor',
                child: Text(alert.recommendation),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, Routes.indicator,
                    arguments: alert.spec.id),
                icon: const Icon(Icons.show_chart),
                label: Text('Ver indicador: ${alert.spec.name}'),
              ),
              const SectionTitle('Decisão humana'),
              _DecisionPanel(alert: alert, decision: decision),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Gerado em ${fmtDateTime(alert.generatedAt)} · id ${alert.id}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          );
        }),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.child});
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(title,
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                child,
              ],
            ),
          ),
        ),
      );
}

class _DecisionPanel extends StatelessWidget {
  const _DecisionPanel({required this.alert, required this.decision});
  final Alert alert;
  final AlertDecision? decision;

  Future<void> _decide(BuildContext context, DecisionStatus status) async {
    final decisions = context.read<DecisionsState>();
    final messenger = ScaffoldMessenger.of(context);
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(status: status),
    );
    if (note == null) return; // cancelado
    await decisions.decide(alert.id, status, note);
    messenger.showSnackBar(SnackBar(
      content: Text('Avaliação registrada: ${status.label.toLowerCase()}.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final d = decision;
    if (d != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(d.status == DecisionStatus.revisado
                      ? Icons.check_circle
                      : Icons.block),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('${d.status.label} em ${fmtDateTime(d.decidedAt)}',
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                ],
              ),
              if (d.note.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('Nota: ${d.note}'),
              ],
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: () => context.read<DecisionsState>().undo(alert.id),
                icon: const Icon(Icons.undo),
                label: const Text('Desfazer avaliação'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Registre sua avaliação deste alerta. O registro serve para histórico e '
          'transparência — não aciona nenhuma ação automática.',
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: () => _decide(context, DecisionStatus.revisado),
          icon: const Icon(Icons.check),
          label: const Text('Marcar como revisado'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => _decide(context, DecisionStatus.descartado),
          icon: const Icon(Icons.block),
          label: const Text('Descartar alerta'),
        ),
      ],
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.status});
  final DecisionStatus status;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.status == DecisionStatus.revisado
            ? 'Marcar como revisado'
            : 'Descartar alerta'),
        content: TextField(
          controller: _controller,
          maxLength: 200,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Nota (opcional)',
            hintText: 'Ex.: equipe de vistoria acionada manualmente',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, _controller.text),
            child: const Text('Confirmar'),
          ),
        ],
      );
}
