import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/territory.dart';
import '../../domain/validators.dart';
import '../../state/occurrences_state.dart';

/// Formulário de registro de ocorrência pelo cidadão, com validação e
/// bloqueio de dados pessoais na descrição.
class OccurrenceFormScreen extends StatefulWidget {
  const OccurrenceFormScreen({super.key});

  @override
  State<OccurrenceFormScreen> createState() => _OccurrenceFormScreenState();
}

class _OccurrenceFormScreenState extends State<OccurrenceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _dateText = TextEditingController();
  OccurrenceCategory? _category;
  String? _district;
  DateTime? _date;
  bool _agreed = false;
  bool _submitting = false;
  bool _triedSubmit = false;

  @override
  void initState() {
    super.initState();
    _setDate(dateOnly(DateTime.now()));
  }

  @override
  void dispose() {
    _description.dispose();
    _dateText.dispose();
    super.dispose();
  }

  void _setDate(DateTime d) {
    _date = d;
    _dateText.text = fmtFullDate(d);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now.subtract(const Duration(days: Validators.maxDaysBack)),
      lastDate: now,
      helpText: 'Data da ocorrência',
    );
    if (picked != null) setState(() => _setDate(picked));
  }

  Future<void> _submit() async {
    setState(() => _triedSubmit = true);
    final messenger = ScaffoldMessenger.of(context);
    if (!_formKey.currentState!.validate()) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Corrija os campos destacados em vermelho.'),
      ));
      return;
    }
    setState(() => _submitting = true);
    final navigator = Navigator.of(context);
    final occurrence = Occurrence(
      id: Occurrence.newAnonymousId(),
      category: _category!,
      district: _district!,
      description: _description.text.trim(),
      date: _date!,
      createdAt: DateTime.now(),
    );
    await context.read<OccurrencesState>().add(occurrence);
    messenger.showSnackBar(SnackBar(
      content: Text('Ocorrência #${occurrence.shortId} registrada anonimamente.'),
    ));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const gap = SizedBox(height: AppSpacing.md);
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar ocorrência')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: _triedSubmit
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
            children: [
              Text(
                'Campos com * são obrigatórios. Não inclua nome, telefone, '
                'e-mail ou CPF: o registro é anônimo.',
                style: theme.textTheme.bodyMedium,
              ),
              gap,
              DropdownButtonFormField<OccurrenceCategory>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Categoria *'),
                items: [
                  for (final c in OccurrenceCategory.values)
                    DropdownMenuItem(
                      value: c,
                      child: Row(
                        children: [
                          Icon(c.icon, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(child: Text(c.label, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _category = v),
                validator: (v) => Validators.selection(v, 'uma categoria'),
              ),
              gap,
              DropdownButtonFormField<String>(
                initialValue: _district,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Distrito *',
                  helperText: 'Usamos só o distrito — nunca a sua localização exata.',
                ),
                items: [
                  for (final d in Territory.districts)
                    DropdownMenuItem(value: d, child: Text(d)),
                ],
                onChanged: (v) => setState(() => _district = v),
                validator: (v) => Validators.selection(v, 'o distrito'),
              ),
              gap,
              TextFormField(
                controller: _dateText,
                readOnly: true,
                onTap: _pickDate,
                decoration: InputDecoration(
                  labelText: 'Data da ocorrência *',
                  suffixIcon: IconButton(
                    tooltip: 'Escolher data',
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _pickDate,
                  ),
                ),
                validator: (_) => Validators.occurrenceDate(_date),
              ),
              gap,
              TextFormField(
                controller: _description,
                maxLines: 4,
                maxLength: Validators.descriptionMax,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descrição *',
                  hintText: 'Ex.: Bueiro entupido na esquina, água acumulando na calçada.',
                  helperText: 'Mínimo de ${Validators.descriptionMin} caracteres.',
                  alignLabelWithHint: true,
                ),
                validator: Validators.description,
              ),
              gap,
              FormField<bool>(
                initialValue: _agreed,
                validator: Validators.consent,
                builder: (field) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      value: _agreed,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                          'Autorizo o uso anônimo deste registro para análise do território. *'),
                      onChanged: (v) {
                        setState(() => _agreed = v ?? false);
                        field.didChange(_agreed);
                      },
                    ),
                    if (field.hasError)
                      Text(
                        field.errorText!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: const Text('Enviar registro'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
