import 'package:flutter_test/flutter_test.dart';
import 'package:territorio_vivo/data/territory.dart';
import 'package:territorio_vivo/domain/validators.dart';

void main() {
  group('descrição da ocorrência', () {
    test('obrigatória e com tamanho mínimo', () {
      expect(Validators.description(''), isNotNull);
      expect(Validators.description('   '), isNotNull);
      expect(Validators.description('curta'), contains('pelo menos'));
    });

    test('rejeita dados pessoais', () {
      const base = 'Bueiro entupido, falar com ';
      expect(Validators.description('$base joao@email.com'), contains('dados pessoais'));
      expect(Validators.description('$base (11) 98765-4321'), contains('dados pessoais'));
      expect(Validators.description('$base CPF 123.456.789-00'), contains('dados pessoais'));
    });

    test('aceita descrição válida', () {
      expect(Validators.description('Bueiro entupido na esquina, água acumulando.'), isNull);
    });

    test('limita tamanho máximo', () {
      expect(Validators.description('a' * 501), contains('no máximo'));
    });
  });

  group('data da ocorrência', () {
    final now = DateTime(2026, 11, 18, 15);
    test('obrigatória', () => expect(Validators.occurrenceDate(null, now: now), isNotNull));
    test('não pode ser futura', () {
      expect(Validators.occurrenceDate(DateTime(2026, 11, 19), now: now), contains('futuro'));
    });
    test('no máximo 30 dias atrás', () {
      expect(Validators.occurrenceDate(DateTime(2026, 10, 1), now: now), isNotNull);
      expect(Validators.occurrenceDate(DateTime(2026, 11, 18), now: now), isNull);
      expect(Validators.occurrenceDate(DateTime(2026, 10, 19), now: now), isNull);
    });
  });

  group('limiar', () {
    final temp = IndicatorSpec.byId('temp_max'); // faixa 20..45
    test('aceita vírgula decimal', () {
      expect(Validators.parseNumber('32,5'), 32.5);
      expect(Validators.threshold('32,5', temp), isNull);
    });
    test('rejeita vazio, texto e fora da faixa', () {
      expect(Validators.threshold('', temp), isNotNull);
      expect(Validators.threshold('abc', temp), contains('números'));
      expect(Validators.threshold('10', temp), contains('entre'));
      expect(Validators.threshold('50', temp), contains('entre'));
    });
  });

  test('consentimento obrigatório', () {
    expect(Validators.consent(false), isNotNull);
    expect(Validators.consent(null), isNotNull);
    expect(Validators.consent(true), isNull);
  });
}
