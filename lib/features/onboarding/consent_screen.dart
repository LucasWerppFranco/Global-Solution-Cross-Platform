import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../data/territory.dart';
import '../../state/settings_state.dart';

/// Consentimento explícito (LGPD) no primeiro uso. Com [reviewOnly], apenas
/// exibe o termo novamente (acessado pelos Ajustes).
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key, this.reviewOnly = false});
  final bool reviewOnly;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _agreed = false;

  Future<void> _accept() async {
    final navigator = Navigator.of(context);
    await context.read<SettingsState>().setConsent(true);
    navigator.pushNamedAndRemoveUntil(Routes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: widget.reviewOnly ? AppBar(title: const Text('Termo de uso')) : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Icon(Icons.shield_outlined, size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  header: true,
                  child: Text('Território Vivo',
                      style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
                ),
                const Text(
                  'Central de inteligência territorial · ${Territory.name}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                const _ConsentItem(
                  icon: Icons.insights,
                  title: 'O que o app faz',
                  text: 'Mostra indicadores de clima, recursos e serviços do território '
                      'e gera alertas preditivos com evidências, nível de confiança e limitações.',
                ),
                const _ConsentItem(
                  icon: Icons.person_off_outlined,
                  title: 'Dados pessoais',
                  text: 'Não coletamos nome, e-mail, telefone nem GPS. Ocorrências são '
                      'registradas com um código aleatório e apenas o distrito.',
                ),
                const _ConsentItem(
                  icon: Icons.phone_android,
                  title: 'Onde ficam os dados',
                  text: 'Tudo fica salvo somente neste aparelho. Você pode apagar a '
                      'qualquer momento em Ajustes › Privacidade.',
                ),
                const _ConsentItem(
                  icon: Icons.how_to_reg,
                  title: 'A decisão é humana',
                  text: 'Os alertas apoiam, mas não substituem, a decisão de gestores '
                      'públicos. O app não executa nenhuma ação automática.',
                ),
                const SizedBox(height: AppSpacing.md),
                if (widget.reviewOnly)
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fechar'),
                  )
                else ...[
                  CheckboxListTile(
                    value: _agreed,
                    onChanged: (v) => setState(() => _agreed = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Li e concordo com o uso dos dados descrito acima.'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton(
                    onPressed: _agreed ? _accept : null,
                    child: const Text('Aceitar e continuar'),
                  ),
                  if (!_agreed)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        'Marque a caixa acima para continuar.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsentItem extends StatelessWidget {
  const _ConsentItem({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(text),
                ],
              ),
            ),
          ],
        ),
      );
}
