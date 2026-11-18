import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/widgets/state_views.dart';
import '../../state/occurrences_state.dart';

/// Ocorrências registradas por cidadãos neste aparelho (offline).
class OccurrencesScreen extends StatelessWidget {
  const OccurrencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<OccurrencesState>();
    final items = state.items;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ocorrências cidadãs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, Routes.occurrenceForm),
        icon: const Icon(Icons.add),
        label: const Text('Registrar'),
        tooltip: 'Registrar nova ocorrência',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Text(
                      'Registros anônimos: só guardamos categoria, distrito, data e '
                      'descrição, identificados por um código aleatório. Ficam '
                      'salvos neste aparelho e funcionam sem internet.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (items.isEmpty)
            const EmptyState(
              icon: Icons.inbox_outlined,
              title: 'Nenhuma ocorrência ainda',
              message: 'Viu um alagamento, lixo acumulado ou fila na UBS? '
                  'Toque em "Registrar" para informar a gestão do território.',
            )
          else
            for (final o in items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Dismissible(
                  key: ValueKey(o.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(AppSpacing.radius),
                    ),
                    child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
                  ),
                  onDismissed: (_) {
                    state.remove(o.id);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Ocorrência #${o.shortId} removida.'),
                      action: SnackBarAction(
                          label: 'Desfazer', onPressed: () => state.add(o)),
                    ));
                  },
                  child: Card(
                    child: ListTile(
                      leading: Icon(o.category.icon, color: theme.colorScheme.primary),
                      title: Text(o.category.label),
                      subtitle: Text(
                          '${o.district} · ${fmtFullDate(o.date)} · #${o.shortId}\n'
                          '${o.description}'),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: 'Excluir ocorrência #${o.shortId}',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => state.remove(o.id),
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
