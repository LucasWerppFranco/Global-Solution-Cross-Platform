/// Nomes das rotas do app. A tabela rota → tela fica em `lib/app.dart`.
///
/// Argumentos:
/// - [dashboard]: `Panel`
/// - [indicator]: `String` (id do indicador)
/// - [alert]: `String` (id do alerta)
/// - [consent]: `bool?` (true = apenas revisar o termo)
abstract final class Routes {
  static const home = '/';
  static const consent = '/consent';
  static const dashboard = '/dashboard';
  static const indicator = '/indicator';
  static const alert = '/alert';
  static const occurrenceForm = '/occurrences/new';
  static const thresholds = '/settings/thresholds';
}
