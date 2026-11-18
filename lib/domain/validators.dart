import '../core/format.dart';
import '../data/territory.dart';

/// Validações dos formulários. Retornam a mensagem de erro ou null se válido.
abstract final class Validators {
  static final _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
  static final _cpf = RegExp(r'\d{3}\.?\d{3}\.?\d{3}-?\d{2}');
  static final _phone = RegExp(r'(\(?\d{2}\)?\s?)?9?\d{4}[\s-]?\d{4}');

  static const descriptionMin = 10;
  static const descriptionMax = 500;
  static const maxDaysBack = 30;

  static String? description(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Descreva a ocorrência.';
    if (text.length < descriptionMin) {
      return 'Use pelo menos $descriptionMin caracteres (atual: ${text.length}).';
    }
    if (text.length > descriptionMax) {
      return 'Use no máximo $descriptionMax caracteres.';
    }
    if (_email.hasMatch(text) || _cpf.hasMatch(text) || _phone.hasMatch(text)) {
      return 'Remova dados pessoais (e-mail, telefone ou CPF): o registro é anônimo.';
    }
    return null;
  }

  static String? occurrenceDate(DateTime? date, {DateTime? now}) {
    if (date == null) return 'Informe a data da ocorrência.';
    final days = daysBetween(date, now ?? DateTime.now());
    if (days < 0) return 'A data não pode estar no futuro.';
    if (days > maxDaysBack) {
      return 'Registre apenas ocorrências dos últimos $maxDaysBack dias.';
    }
    return null;
  }

  static String? selection(Object? value, String what) =>
      value == null ? 'Selecione $what.' : null;

  static String? consent(bool? agreed) =>
      agreed == true ? null : 'É preciso autorizar o uso anônimo do registro.';

  /// Aceita vírgula ou ponto como separador decimal.
  static double? parseNumber(String? value) =>
      double.tryParse((value ?? '').trim().replaceAll(',', '.'));

  static String? threshold(String? value, IndicatorSpec spec) {
    if ((value ?? '').trim().isEmpty) return 'Informe o limiar.';
    final n = parseNumber(value);
    if (n == null) return 'Use apenas números (ex.: 32,5).';
    if (n < spec.minThreshold || n > spec.maxThreshold) {
      return 'Valor deve ficar entre ${fmtNum(spec.minThreshold, spec.decimals)} '
          'e ${fmtNum(spec.maxThreshold, spec.decimals)} ${spec.unit}.';
    }
    return null;
  }
}
