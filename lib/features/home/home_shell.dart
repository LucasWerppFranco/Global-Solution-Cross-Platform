import 'package:flutter/material.dart';

import '../alerts/alerts_screen.dart';
import '../occurrences/occurrences_screen.dart';
import '../settings/settings_screen.dart';
import 'overview_screen.dart';

/// Navegação principal por abas. A aba selecionada é estado local da tela;
/// IndexedStack preserva a rolagem/filtros de cada aba.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: _index,
          children: const [
            OverviewScreen(),
            AlertsScreen(),
            OccurrencesScreen(),
            SettingsScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Visão geral'),
            NavigationDestination(
                icon: Icon(Icons.notifications_outlined),
                selectedIcon: Icon(Icons.notifications),
                label: 'Alertas'),
            NavigationDestination(
                icon: Icon(Icons.report_outlined),
                selectedIcon: Icon(Icons.report),
                label: 'Ocorrências'),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Ajustes'),
          ],
        ),
      );
}
