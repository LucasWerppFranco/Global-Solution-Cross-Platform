import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:territorio_vivo/core/widgets/alert_widgets.dart';
import 'package:territorio_vivo/core/widgets/state_views.dart';
import 'package:territorio_vivo/data/models.dart';
import 'package:territorio_vivo/data/territory.dart';
import 'package:territorio_vivo/domain/alert_engine.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('aviso de decisão humana é exibido', (tester) async {
    await tester.pumpWidget(_wrap(const HumanDecisionBanner()));
    expect(find.textContaining('não substitui, a decisão humana'), findsOneWidget);
  });

  testWidgets('AlertTile mostra severidade, confiança e é acessível', (tester) async {
    final indicator = Indicator(
      spec: IndicatorSpec.byId('agua'),
      history: [
        for (var i = 0; i < 20; i++) DataPoint(DateTime(2026, 11, 1 + i), 900),
        DataPoint(DateTime(2026, 11, 21), 1200),
      ],
    );
    final alert = AlertEngine.generate(
      indicators: [indicator],
      thresholds: {'agua': 950},
      generatedAt: DateTime(2026, 11, 22),
    ).single;

    await tester.pumpWidget(_wrap(AlertTile(alert: alert)));
    // O pulso do alerta crítico é finito: pumpAndSettle falharia se fosse infinito.
    expect(find.byType(ScaleTransition), findsWidgets);
    await tester.pumpAndSettle();

    expect(find.text('Consumo de água acima do limiar'), findsOneWidget);
    expect(find.text('Crítico'), findsOneWidget);
    expect(find.textContaining('Confiança'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Alerta Crítico')), findsWidgets);
  });

  testWidgets('EmptyState exibe título, mensagem e ação', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(EmptyState(
      icon: Icons.inbox_outlined,
      title: 'Nada aqui',
      message: 'Lista vazia',
      action: TextButton(onPressed: () => tapped = true, child: const Text('Criar')),
    )));
    expect(find.text('Nada aqui'), findsOneWidget);
    await tester.tap(find.text('Criar'));
    expect(tapped, isTrue);
  });
}
