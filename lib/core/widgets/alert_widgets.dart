import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../domain/alert_engine.dart';
import '../routes.dart';
import '../theme.dart';

extension SeverityStyle on Severity {
  Color get color => switch (this) {
        Severity.critico => AppColors.critical,
        Severity.atencao => AppColors.attention,
        Severity.info => AppColors.info,
      };

  IconData get icon => switch (this) {
        Severity.critico => Icons.error,
        Severity.atencao => Icons.warning_amber_rounded,
        Severity.info => Icons.info_outline,
      };
}

/// Aviso obrigatório: o alerta apoia, mas não substitui, a decisão humana.
class HumanDecisionBanner extends StatelessWidget {
  const HumanDecisionBanner({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
        child: Row(
          children: [
            Icon(Icons.how_to_reg, color: scheme.onSecondaryContainer),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                compact
                    ? 'Os alertas apoiam, mas não substituem, a decisão humana.'
                    : 'Este alerta apoia, mas não substitui, a decisão humana. '
                        'Nenhuma ação é executada automaticamente: cabe ao gestor '
                        'público avaliar o contexto e decidir.',
                style: TextStyle(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SeverityChip extends StatelessWidget {
  const SeverityChip(this.severity, {super.key});
  final Severity severity;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Severidade ${severity.label}',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: severity.color,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(severity.icon, size: 16, color: Colors.white),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  severity.label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
}

class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge({super.key, required this.alert});
  final Alert alert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = (alert.confidenceScore * 100).round();
    final label = 'Confiança ${alert.confidence.label} ($pct%)';
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(label, style: Theme.of(context).textTheme.labelMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class AlertTile extends StatelessWidget {
  const AlertTile({super.key, required this.alert, this.decision});
  final Alert alert;
  final AlertDecision? decision;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () =>
              Navigator.pushNamed(context, Routes.alert, arguments: alert.id),
          child: Semantics(
            button: true,
            label: 'Alerta ${alert.severity.label}: ${alert.title}. '
                '${alert.summary} Confiança ${alert.confidence.label}. '
                '${decision?.status.label ?? 'Aguardando avaliação humana'}. '
                'Toque para ver justificativa e limitações.',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CriticalPulse(
                    enabled: alert.severity == Severity.critico,
                    child: CircleAvatar(
                      backgroundColor: alert.severity.color,
                      child: Icon(alert.severity.icon, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(alert.title, style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.xs),
                        Text(alert.summary,
                            maxLines: 3, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: [
                            SeverityChip(alert.severity),
                            ConfidenceBadge(alert: alert),
                            if (decision != null)
                              Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: Icon(
                                  decision!.status == DecisionStatus.revisado
                                      ? Icons.check_circle_outline
                                      : Icons.block,
                                  size: 16,
                                ),
                                label: Text(decision!.status.label),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Três pulsos curtos ao exibir um alerta crítico: chama a atenção para a
/// prioridade sem animar indefinidamente (não distrai nem cansa a leitura).
class _CriticalPulse extends StatefulWidget {
  const _CriticalPulse({required this.enabled, required this.child});
  final bool enabled;
  final Widget child;

  @override
  State<_CriticalPulse> createState() => _CriticalPulseState();
}

class _CriticalPulseState extends State<_CriticalPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));
  late final Animation<double> _scale = TweenSequence<double>([
    for (var i = 0; i < 3; i++) ...[
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.18)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 1),
      TweenSequenceItem(
          tween: Tween(begin: 1.18, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 1),
    ],
  ]).animate(_controller);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.enabled &&
        !MediaQuery.disableAnimationsOf(context) &&
        _controller.isDismissed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}
