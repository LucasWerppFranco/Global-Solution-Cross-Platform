import 'package:flutter/material.dart' show IconData, Icons;

import 'models.dart';

/// Território monitorado: Subprefeitura Sé, centro de São Paulo/SP.
abstract final class Territory {
  static const name = 'Subprefeitura Sé — São Paulo/SP';
  static const shortName = 'Sé · São Paulo';
  static const latitude = -23.5505;
  static const longitude = -46.6333;

  /// População residente (IBGE, Censo 2010, 8 distritos da subprefeitura).
  static const population = 431106;

  static const districts = [
    'Bela Vista',
    'Bom Retiro',
    'Cambuci',
    'Consolação',
    'Liberdade',
    'República',
    'Santa Cecília',
    'Sé',
  ];
}

/// Metadados de cada indicador: fonte, limiar padrão, faixa válida,
/// limitações conhecidas e público beneficiado (indicador social).
class IndicatorSpec {
  const IndicatorSpec({
    required this.id,
    required this.name,
    required this.unit,
    required this.panel,
    required this.icon,
    required this.defaultThreshold,
    required this.minThreshold,
    required this.maxThreshold,
    required this.decimals,
    required this.synthetic,
    required this.source,
    required this.beneficiaries,
    required this.beneficiariesNote,
    required this.limitation,
    required this.recommendation,
  });

  final String id;
  final String name;
  final String unit;
  final Panel panel;
  final IconData icon;

  /// Valores acima do limiar são considerados piores (todos os indicadores
  /// deste app seguem essa convenção).
  final double defaultThreshold;
  final double minThreshold;
  final double maxThreshold;
  final int decimals;
  final bool synthetic;
  final String source;

  /// Estimativa de moradores beneficiados quando um alerta deste indicador
  /// é avaliado por um gestor (base do indicador de benefício social).
  final int beneficiaries;
  final String beneficiariesNote;
  final String limitation;
  final String recommendation;

  static IndicatorSpec byId(String id) => all.firstWhere((s) => s.id == id);

  static IndicatorSpec? tryById(String id) =>
      all.where((s) => s.id == id).firstOrNull;

  static Map<String, double> get defaultThresholds =>
      {for (final s in all) s.id: s.defaultThreshold};

  static const all = <IndicatorSpec>[
    IndicatorSpec(
      id: 'temp_max',
      name: 'Temperatura máxima',
      unit: '°C',
      panel: Panel.clima,
      icon: Icons.thermostat,
      defaultThreshold: 32,
      minThreshold: 20,
      maxThreshold: 45,
      decimals: 1,
      synthetic: false,
      source: 'Open-Meteo Forecast API (dados reais)',
      beneficiaries: 60000,
      beneficiariesNote: 'idosos e crianças pequenas, mais vulneráveis ao calor (~14% da população)',
      limitation:
          'Modelo meteorológico em grade de ~11 km: não captura ilhas de calor de ruas específicas.',
      recommendation:
          'Avaliar abertura de pontos de hidratação e reforço de orientação a grupos vulneráveis.',
    ),
    IndicatorSpec(
      id: 'precip',
      name: 'Chuva diária',
      unit: 'mm',
      panel: Panel.clima,
      icon: Icons.umbrella,
      defaultThreshold: 30,
      minThreshold: 5,
      maxThreshold: 150,
      decimals: 1,
      synthetic: false,
      source: 'Open-Meteo Forecast API (dados reais)',
      beneficiaries: 25000,
      beneficiariesNote: 'moradores de pontos históricos de alagamento (Bom Retiro, Cambuci)',
      limitation:
          'Chuvas convectivas de verão são localizadas: volumes podem variar muito entre bairros vizinhos.',
      recommendation:
          'Avaliar vistoria de bocas de lobo e acionamento preventivo da Defesa Civil.',
    ),
    IndicatorSpec(
      id: 'pm25',
      name: 'Material particulado PM2.5',
      unit: 'µg/m³',
      panel: Panel.clima,
      icon: Icons.air,
      defaultThreshold: 25,
      minThreshold: 5,
      maxThreshold: 100,
      decimals: 1,
      synthetic: false,
      source: 'Open-Meteo Air Quality API — modelo CAMS (dados reais)',
      beneficiaries: 40000,
      beneficiariesNote: 'pessoas com asma, DPOC e outras doenças respiratórias',
      limitation:
          'Modelo de resolução regional; não substitui as estações de monitoramento da CETESB.',
      recommendation:
          'Avaliar comunicação de risco a pessoas com doenças respiratórias e às escolas.',
    ),
    IndicatorSpec(
      id: 'agua',
      name: 'Consumo de água',
      unit: 'mil m³/dia',
      panel: Panel.recursos,
      icon: Icons.water_drop_outlined,
      defaultThreshold: 950,
      minThreshold: 500,
      maxThreshold: 1500,
      decimals: 0,
      synthetic: true,
      source: 'Série sintética (simula API da concessionária)',
      beneficiaries: 120000,
      beneficiariesNote: 'domicílios sujeitos a rodízio ou falta de água',
      limitation:
          'Em produção dependeria de telemetria da concessionária por setor de abastecimento.',
      recommendation:
          'Avaliar campanha de uso consciente e inspeção de vazamentos na rede.',
    ),
    IndicatorSpec(
      id: 'energia',
      name: 'Consumo de energia',
      unit: 'MWh/dia',
      panel: Panel.recursos,
      icon: Icons.bolt,
      defaultThreshold: 4200,
      minThreshold: 2000,
      maxThreshold: 8000,
      decimals: 0,
      synthetic: true,
      source: 'Série sintética (simula API da distribuidora)',
      beneficiaries: 80000,
      beneficiariesNote: 'moradores em áreas com histórico de sobrecarga da rede',
      limitation:
          'Não diferencia consumo residencial, comercial e público.',
      recommendation:
          'Avaliar contato com a distribuidora sobre risco de sobrecarga no horário de pico.',
    ),
    IndicatorSpec(
      id: 'residuos',
      name: 'Resíduos coletados',
      unit: 't/dia',
      panel: Panel.recursos,
      icon: Icons.recycling,
      defaultThreshold: 520,
      minThreshold: 200,
      maxThreshold: 1000,
      decimals: 0,
      synthetic: true,
      source: 'Série sintética (simula dados de coleta)',
      beneficiaries: 50000,
      beneficiariesNote: 'moradores de vias com pontos viciados de descarte',
      limitation:
          'Não inclui descarte irregular, que não passa pela pesagem da coleta.',
      recommendation:
          'Avaliar reforço da coleta e fiscalização de descarte irregular.',
    ),
    IndicatorSpec(
      id: 'ubs',
      name: 'Atendimentos em UBS',
      unit: 'atend./dia',
      panel: Panel.servicos,
      icon: Icons.local_hospital_outlined,
      defaultThreshold: 1300,
      minThreshold: 500,
      maxThreshold: 3000,
      decimals: 0,
      synthetic: true,
      source: 'Série sintética (simula dados das UBS)',
      beneficiaries: 30000,
      beneficiariesNote: 'usuários das UBS do território em semanas de alta demanda',
      limitation:
          'Mede atendimentos realizados, não a demanda reprimida (quem desistiu da fila).',
      recommendation:
          'Avaliar remanejamento de equipes ou ampliação de horário nas UBS mais demandadas.',
    ),
    IndicatorSpec(
      id: 'zeladoria',
      name: 'Chamados de zeladoria (156)',
      unit: 'chamados/dia',
      panel: Panel.servicos,
      icon: Icons.support_agent,
      defaultThreshold: 180,
      minThreshold: 50,
      maxThreshold: 500,
      decimals: 0,
      synthetic: true,
      source: 'Série sintética (simula a central 156)',
      beneficiaries: 15000,
      beneficiariesNote: 'moradores afetados por problemas de zeladoria urbana',
      limitation:
          'Depende de a população registrar chamados: regiões que reclamam menos parecem ter menos problemas.',
      recommendation:
          'Avaliar priorização das equipes de zeladoria por distrito.',
    ),
  ];
}
