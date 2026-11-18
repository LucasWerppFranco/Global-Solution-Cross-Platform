import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/territory_state.dart';
import '../format.dart';
import '../theme.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  static const message = 'Carregando dados do território…';

  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          liveRegion: true,
          label: message,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppSpacing.md),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 56, color: theme.colorScheme.error),
            const SizedBox(height: AppSpacing.md),
            Text('Não foi possível carregar',
                style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: AppSpacing.md), action!],
        ],
      ),
    );
  }
}

/// Envolve qualquer tela que dependa dos dados do território e trata
/// carregamento, erro e dados com uma transição suave entre eles.
class TerritoryBody extends StatelessWidget {
  const TerritoryBody({super.key, required this.builder});
  final Widget Function(BuildContext context, TerritorySnapshot snapshot) builder;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TerritoryState>();
    final child = switch (state.status) {
      LoadStatus.loading => const LoadingView(),
      LoadStatus.error => ErrorView(
          message: state.error ?? 'Erro desconhecido.', onRetry: state.load),
      LoadStatus.ready => builder(context, state.snapshot!),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: KeyedSubtree(key: ValueKey(state.status), child: child),
    );
  }
}

/// Mostra a atualidade dos dados e avisa quando o app está usando o cache.
class FreshnessBanner extends StatelessWidget {
  const FreshnessBanner({super.key, required this.snapshot});
  final TerritorySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final when = fmtDateTime(snapshot.fetchedAt);
    if (!snapshot.fromCache) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: [
            Icon(Icons.cloud_done_outlined, size: 18, color: scheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text('Dados atualizados em $when')),
          ],
        ),
      );
    }
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off, color: scheme.onErrorContainer),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Sem conexão: exibindo dados salvos em $when. '
                'A confiança dos alertas foi reduzida.',
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
        child: Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
      );
}

/// Grade responsiva: 1 coluna no celular, 2+ em telas largas (tablet/web).
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({super.key, required this.children, this.minItemWidth = 300});
  final List<Widget> children;
  final double minItemWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final cols = (c.maxWidth / minItemWidth).floor().clamp(1, 4);
          final width = (c.maxWidth - AppSpacing.md * (cols - 1)) / cols;
          return Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [for (final w in children) SizedBox(width: width, child: w)],
          );
        },
      );
}

/// Item de lista com marcador, usado para evidências e limitações.
class BulletList extends StatelessWidget {
  const BulletList(this.items, {super.key, this.icon = Icons.circle});
  final List<String> items;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(icon, size: icon == Icons.circle ? 8 : 18, color: color),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(item)),
              ],
            ),
          ),
      ],
    );
  }
}
