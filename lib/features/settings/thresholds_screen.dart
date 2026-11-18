import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models.dart';
import '../../data/territory.dart';
import '../../domain/validators.dart';
import '../../state/settings_state.dart';

/// Formulário de configuração dos limiares de alerta (uso do gestor).
class ThresholdsScreen extends StatefulWidget {
  const ThresholdsScreen({super.key});

  @override
  State<ThresholdsScreen> createState() => _ThresholdsScreenState();
}

class _ThresholdsScreenState extends State<ThresholdsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsState>();
    _controllers = {
      for (final s in IndicatorSpec.all)
        s.id: TextEditingController(
            text: fmtNum(settings.thresholdFor(s.id), s.decimals)),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _restoreDefaults() {
    for (final s in IndicatorSpec.all) {
      _controllers[s.id]!.text = fmtNum(s.defaultThreshold, s.decimals);
    }
    _formKey.currentState?.validate();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!_formKey.currentState!.validate()) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Há limiares inválidos. Veja as mensagens em vermelho.'),
      ));
      return;
    }
    final navigator = Navigator.of(context);
    await context.read<SettingsState>().setThresholds({
      for (final e in _controllers.entries) e.key: Validators.parseNumber(e.value.text)!,
    });
    messenger.showSnackBar(const SnackBar(
      content: Text('Limiares salvos. Os alertas foram recalculados.'),
    ));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Limiares de alerta'),
          actions: [
            TextButton(onPressed: _restoreDefaults, child: const Text('Padrões')),
          ],
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
              children: [
                const Text(
                  'Um alerta é gerado quando o valor observado, a previsão oficial ou '
                  'a tendência dos próximos 7 dias atinge o limiar. Limiares baixos '
                  'geram mais alertas (mais falsos positivos); altos, menos alertas '
                  '(risco de perder eventos).',
                ),
                for (final panel in Panel.values) ...[
                  SectionTitle(panel.label),
                  for (final s in IndicatorSpec.all.where((s) => s.panel == panel))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: TextFormField(
                        controller: _controllers[s.id],
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: s.name,
                          suffixText: s.unit,
                          prefixIcon: Icon(s.icon),
                          helperText: 'Entre ${fmtNum(s.minThreshold, s.decimals)} e '
                              '${fmtNum(s.maxThreshold, s.decimals)} · padrão '
                              '${fmtNum(s.defaultThreshold, s.decimals)}',
                        ),
                        validator: (v) => Validators.threshold(v, s),
                      ),
                    ),
                ],
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Salvar limiares'),
                ),
              ],
            ),
          ),
        ),
      );
}
