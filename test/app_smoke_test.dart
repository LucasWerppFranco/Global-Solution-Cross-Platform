// Teste de fumaça: abre o app completo (API simulada) e percorre todas as
// telas em tamanho de celular, tablet e com fonte ampliada. Qualquer exceção
// ou overflow de layout faz o teste falhar.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:territorio_vivo/app.dart';
import 'package:territorio_vivo/core/format.dart';
import 'package:territorio_vivo/core/routes.dart';
import 'package:territorio_vivo/core/widgets/alert_widgets.dart';
import 'package:territorio_vivo/data/local_store.dart';
import 'package:territorio_vivo/data/models.dart';
import 'package:territorio_vivo/data/open_meteo_api.dart';

String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Respostas no formato da Open-Meteo: 30 dias passados + 7 de previsão,
/// com uma previsão de 34 °C (gera alerta) e lacunas nulas.
OpenMeteoApi _fakeMeteo() {
  final today = dateOnly(DateTime.now());
  final days = [for (var i = -30; i < 7; i++) DateTime(today.year, today.month, today.day + i)];
  final forecast = {
    'daily': {
      'time': [for (final d in days) _day(d)],
      'temperature_2m_max': [for (var i = 0; i < days.length; i++) i == 32 ? 34.0 : 26.0 + i % 3],
      'precipitation_sum': [for (var i = 0; i < days.length; i++) i % 5 == 0 ? null : 2.5],
    },
  };
  final hours = [
    for (final d in days.take(34))
      for (var h = 0; h < 24; h++) '${_day(d)}T${h.toString().padLeft(2, '0')}:00'
  ];
  final air = {
    'hourly': {
      'time': hours,
      'pm2_5': [for (var i = 0; i < hours.length; i++) 10.0 + i % 7],
    },
  };
  return OpenMeteoApi(
    client: MockClient((req) async => http.Response(
        jsonEncode(req.url.host.startsWith('air') ? air : forecast), 200)),
  );
}

Future<void> _pumpApp(WidgetTester tester, Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = LocalStore(await SharedPreferences.getInstance());
  await tester.pumpWidget(appWithState(store, meteo: _fakeMeteo()));
  await tester.pumpAndSettle();
}

void _setSize(WidgetTester tester, Size logical) {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = logical * 2;
  addTearDown(tester.view.reset);
}

Future<void> _visit(WidgetTester tester, String route, [Object? args]) async {
  final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
  nav.pushNamed(route, arguments: args);
  await tester.pumpAndSettle();
  expect(find.text('Página não encontrada'), findsNothing, reason: route);
  nav.pop();
  await tester.pumpAndSettle();
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(
      of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

/// Rola a lista visível até [finder] ser construído e aparecer na tela.
Future<Finder> _scrollTo(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 15 && finder.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  return finder.first;
}

/// Percorre abas, os 3 painéis, indicador, alerta e formulários.
Future<void> _tour(WidgetTester tester) async {
  expect(find.text('Benefício social'), findsOneWidget);
  for (final p in Panel.values) {
    await _visit(tester, Routes.dashboard, p);
  }
  await _visit(tester, Routes.indicator, 'temp_max');
  await _visit(tester, Routes.indicator, 'agua');
  await _visit(tester, Routes.thresholds);
  await _visit(tester, Routes.occurrenceForm);
  await _visit(tester, Routes.consent, true);

  await _tapTab(tester, 'Alertas');
  final tile = await _scrollTo(tester, find.byType(AlertTile));
  await tester.tap(tile);
  await tester.pumpAndSettle();
  final banner =
      await _scrollTo(tester, find.textContaining('não substitui, a decisão humana'));
  expect(banner, findsOneWidget);
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await tester.pumpAndSettle();

  await _tapTab(tester, 'Ocorrências');
  await _tapTab(tester, 'Ajustes');
  await _tapTab(tester, 'Visão geral');
}

void main() {
  testWidgets('fluxo completo no celular, a partir do consentimento', (tester) async {
    _setSize(tester, const Size(390, 844));
    await _pumpApp(tester, {});

    // Sem consentimento: só o termo; o botão fica desabilitado até marcar.
    await tester.scrollUntilVisible(find.text('Aceitar e continuar'), 200);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aceitar e continuar'));
    await tester.pumpAndSettle();

    await _tour(tester);
  });

  testWidgets('formulário de ocorrência: erros, depois envio', (tester) async {
    _setSize(tester, const Size(390, 844));
    await _pumpApp(tester, {'consent_v1': true});
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.pushNamed(Routes.occurrenceForm);
    await tester.pumpAndSettle();

    final send = find.text('Enviar registro');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.text('Selecione uma categoria.'), findsOneWidget);
    expect(find.text('Descreva a ocorrência.'), findsOneWidget);

    await tester.tap(find.text('Categoria *'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alagamento').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Distrito *'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cambuci').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Descrição *'),
        'Rua alagada, ligar (11) 98765-4321');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.textContaining('Remova dados pessoais'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Descrição *'),
        'Rua alagada perto da praça, água na calçada.');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.textContaining('registrada anonimamente'), findsOneWidget);
  });

  testWidgets('tablet com fonte em 200%', (tester) async {
    _setSize(tester, const Size(1024, 1366));
    await _pumpApp(tester, {
      'consent_v1': true,
      'settings_v1': jsonEncode({'fontScale': 2.0}),
    });
    await _tour(tester);
  });

  testWidgets('celular com fonte em 200% e tema escuro de alto contraste', (tester) async {
    _setSize(tester, const Size(360, 740));
    await _pumpApp(tester, {
      'consent_v1': true,
      'settings_v1': jsonEncode(
          {'fontScale': 2.0, 'themeMode': 'dark', 'highContrast': true}),
    });
    await _tour(tester);
  });

  testWidgets('sem conexão e sem cache: mostra erro com "Tentar novamente"', (tester) async {
    _setSize(tester, const Size(390, 844));
    await _pumpApp(tester, {
      'consent_v1': true,
      'settings_v1': jsonEncode({'simulateOffline': true}),
    });
    expect(find.text('Não foi possível carregar'), findsWidgets);
    expect(find.text('Tentar novamente'), findsWidgets);
  });
}
