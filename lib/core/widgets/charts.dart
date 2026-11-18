import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../format.dart';
import '../theme.dart';

/// Gráfico de linha com histórico (linha cheia), previsão/projeção (tracejada)
/// e limiar (tracejado vermelho). Desenhado com CustomPainter: sem dependência
/// externa e com descrição textual para leitores de tela.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.history,
    required this.semanticLabel,
    this.projection = const [],
    this.threshold,
    this.height = 200,
    this.compact = false,
    this.decimals = 0,
  });

  final List<DataPoint> history;
  final List<DataPoint> projection;
  final double? threshold;
  final String semanticLabel;
  final double height;
  final bool compact;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        // Histórico se desenha da esquerda para a direita e, depois, a
        // projeção tracejada: separa visualmente o observado do previsto.
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: AppMotion.of(context),
          curve: Curves.easeOutCubic,
          builder: (context, progress, child) => CustomPaint(
          painter: _TrendPainter(
            progress: progress,
            history: history,
            projection: projection,
            threshold: threshold,
            compact: compact,
            decimals: decimals,
            lineColor: scheme.primary,
            projectionColor: scheme.tertiary,
            thresholdColor: scheme.error,
            gridColor: scheme.outlineVariant,
            labelStyle: theme.textTheme.labelSmall!
                .copyWith(color: scheme.onSurfaceVariant),
            textScaler:
                MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.4),
          ),
        ),
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.progress,
    required this.history,
    required this.projection,
    required this.threshold,
    required this.compact,
    required this.decimals,
    required this.lineColor,
    required this.projectionColor,
    required this.thresholdColor,
    required this.gridColor,
    required this.labelStyle,
    required this.textScaler,
  });

  final double progress; // 0..1: 70% para o histórico, 30% para a projeção
  final List<DataPoint> history;
  final List<DataPoint> projection;
  final double? threshold;
  final bool compact;
  final int decimals;
  final Color lineColor, projectionColor, thresholdColor, gridColor;
  final TextStyle labelStyle;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;
    final values = [
      for (final p in history) p.value,
      for (final p in projection) p.value,
      ?threshold,
    ];
    var minY = values.reduce(math.min);
    var maxY = values.reduce(math.max);
    if (maxY - minY < 1e-9) {
      minY -= 1;
      maxY += 1;
    }
    final pad = (maxY - minY) * 0.1;
    minY -= pad;
    maxY += pad;

    final left = compact ? 0.0 : textScaler.scale(44);
    final bottom = compact ? 0.0 : textScaler.scale(20);
    final chart = Rect.fromLTRB(left, 4, size.width - 4, size.height - bottom);
    final n = history.length + projection.length;
    double xAt(int i) =>
        n == 1 ? chart.center.dx : chart.left + chart.width * i / (n - 1);
    double yAt(double v) =>
        chart.bottom - chart.height * (v - minY) / (maxY - minY);

    if (!compact) {
      final grid = Paint()
        ..color = gridColor
        ..strokeWidth = 1;
      for (var k = 0; k <= 3; k++) {
        final v = minY + (maxY - minY) * k / 3;
        final y = yAt(v);
        canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
        _text(canvas, fmtNum(v, decimals), Offset(0, y - 7), maxWidth: left - 4);
      }
      final lastDate = (projection.isNotEmpty ? projection.last : history.last).date;
      _text(canvas, fmtDate(history.first.date), Offset(chart.left, chart.bottom + 4));
      _text(canvas, fmtDate(lastDate), Offset(chart.right, chart.bottom + 4),
          alignRight: true);
    }

    if (threshold != null) {
      final y = yAt(threshold!);
      _dashed(
        canvas,
        Path()
          ..moveTo(chart.left, y)
          ..lineTo(chart.right, y),
        Paint()
          ..color = thresholdColor
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }

    final line = Path();
    for (var i = 0; i < history.length; i++) {
      final x = xAt(i), y = yAt(history[i].value);
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }
    final histT = (progress / 0.7).clamp(0.0, 1.0);
    final projT = ((progress - 0.7) / 0.3).clamp(0.0, 1.0);
    final fill = Path.from(line)
      ..lineTo(xAt(history.length - 1), chart.bottom)
      ..lineTo(xAt(0), chart.bottom)
      ..close();
    canvas.drawPath(
        fill, Paint()..color = lineColor.withValues(alpha: 0.12 * histT));
    canvas.drawPath(
      _partial(line, histT),
      Paint()
        ..color = lineColor
        ..strokeWidth = compact ? 2 : 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    if (projection.isNotEmpty) {
      final last = history.length - 1;
      final proj = Path()..moveTo(xAt(last), yAt(history.last.value));
      for (var j = 0; j < projection.length; j++) {
        proj.lineTo(xAt(last + 1 + j), yAt(projection[j].value));
      }
      _dashed(
        canvas,
        proj,
        Paint()
          ..color = projectionColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
        upTo: projT,
      );
    }

    if (histT < 1) return;
    canvas.drawCircle(
      Offset(xAt(history.length - 1), yAt(history.last.value)),
      compact ? 3 : 4.5,
      Paint()..color = lineColor,
    );
  }

  /// Trecho inicial do caminho, de 0 até a fração [t] do comprimento.
  Path _partial(Path path, double t) {
    final out = Path();
    for (final m in path.computeMetrics()) {
      out.addPath(m.extractPath(0, m.length * t), Offset.zero);
    }
    return out;
  }

  void _dashed(Canvas canvas, Path path, Paint paint, {double upTo = 1}) {
    for (final m in path.computeMetrics()) {
      final end = m.length * upTo;
      for (var d = 0.0; d < end; d += 10) {
        canvas.drawPath(m.extractPath(d, math.min(d + 6, end)), paint);
      }
    }
  }

  void _text(Canvas canvas, String s, Offset at,
      {double maxWidth = 80, bool alignRight = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: math.max(0, maxWidth));
    tp.paint(canvas, alignRight ? at - Offset(tp.width, 0) : at);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.progress != progress ||
      old.history != history ||
      old.projection != projection ||
      old.threshold != threshold ||
      old.lineColor != lineColor ||
      old.textScaler != textScaler;
}

/// Legenda do TrendChart.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.projectionLabel});
  final String projectionLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget item(Color c, String label, {bool dashed = false}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: dashed ? 2 : 4,
              color: c,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        );
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        item(scheme.primary, 'Observado'),
        item(scheme.tertiary, projectionLabel, dashed: true),
        item(scheme.error, 'Limiar', dashed: true),
      ],
    );
  }
}

/// Barras horizontais simples (ex.: ocorrências por categoria).
class HorizontalBars extends StatelessWidget {
  const HorizontalBars({super.key, required this.items});
  final List<(String label, double value)> items;

  @override
  Widget build(BuildContext context) {
    final max = items.fold(0.0, (m, e) => math.max(m, e.$2));
    return Column(
      children: [
        for (final (label, value) in items)
          Semantics(
            label: '$label: ${fmtNum(value, 0)}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(label)),
                      Text(fmtNum(value, 0),
                          style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AnimatedBar(value: max == 0 ? 0 : value / max),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Barra de progresso que se preenche até [value] (0..1), comunicando a
/// proporção (confiança, consumo em relação ao limiar, contagens).
class AnimatedBar extends StatelessWidget {
  const AnimatedBar({super.key, required this.value, this.minHeight = 10, this.color});
  final double value;
  final double minHeight;
  final Color? color;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0).toDouble()),
        duration: AppMotion.of(context),
        curve: Curves.easeOutCubic,
        builder: (context, v, child) => LinearProgressIndicator(
          value: v,
          minHeight: minHeight,
          color: color,
          borderRadius: BorderRadius.circular(minHeight / 2),
        ),
      );
}
