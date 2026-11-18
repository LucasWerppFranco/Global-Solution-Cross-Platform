import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/routes.dart';
import 'core/theme.dart';
import 'core/widgets/state_views.dart';
import 'data/local_store.dart';
import 'data/models.dart';
import 'data/open_meteo_api.dart';
import 'data/territory_repository.dart';
import 'features/alerts/alert_detail_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/home/home_shell.dart';
import 'features/indicator/indicator_detail_screen.dart';
import 'features/occurrences/occurrence_form_screen.dart';
import 'features/onboarding/consent_screen.dart';
import 'features/settings/thresholds_screen.dart';
import 'state/decisions_state.dart';
import 'state/occurrences_state.dart';
import 'state/settings_state.dart';
import 'state/territory_state.dart';

/// Injeta os estados globais e o repositório. [meteo] permite aos testes
/// substituir a API real por respostas simuladas.
Widget appWithState(LocalStore store, {OpenMeteoApi? meteo}) {
  final settings = SettingsState(store);
  final repository = TerritoryRepository(
    store: store,
    simulateOffline: () => settings.simulateOffline,
    meteo: meteo,
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider(create: (_) => TerritoryState(repository)..load()),
      ChangeNotifierProvider(create: (_) => OccurrencesState(store)),
      ChangeNotifierProvider(create: (_) => DecisionsState(store)),
    ],
    child: const TerritorioVivoApp(),
  );
}

class TerritorioVivoApp extends StatelessWidget {
  const TerritorioVivoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsState>();
    return MaterialApp(
      title: 'Território Vivo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light, highContrast: s.highContrast),
      darkTheme: AppTheme.build(Brightness.dark, highContrast: s.highContrast),
      // Respeita também o "alto contraste" do sistema operacional.
      highContrastTheme: AppTheme.build(Brightness.light, highContrast: true),
      highContrastDarkTheme: AppTheme.build(Brightness.dark, highContrast: true),
      themeMode: s.themeMode,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Escala de fonte do app multiplicada pela do sistema.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(mq.textScaler.scale(1) * s.fontScale),
          ),
          child: child!,
        );
      },
      // Sem consentimento, a única rota inicial é o termo (sem "voltar" para a home).
      onGenerateInitialRoutes: (_) => [
        AppRouter.generate(
            RouteSettings(name: s.hasConsent ? Routes.home : Routes.consent)),
      ],
      onGenerateRoute: AppRouter.generate,
    );
  }
}

/// Tabela de rotas nomeadas com passagem de parâmetros via `arguments`.
abstract final class AppRouter {
  static Route<dynamic> generate(RouteSettings settings) {
    final args = settings.arguments;
    final Widget page = switch (settings.name) {
      Routes.home => const HomeShell(),
      Routes.consent => ConsentScreen(reviewOnly: args == true),
      Routes.dashboard when args is Panel => DashboardScreen(panel: args),
      Routes.indicator when args is String => IndicatorDetailScreen(indicatorId: args),
      Routes.alert when args is String => AlertDetailScreen(alertId: args),
      Routes.occurrenceForm => const OccurrenceFormScreen(),
      Routes.thresholds => const ThresholdsScreen(),
      _ => Scaffold(
          appBar: AppBar(),
          body: const EmptyState(
            icon: Icons.explore_off_outlined,
            title: 'Página não encontrada',
            message: 'O endereço solicitado não existe.',
          ),
        ),
    };
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
