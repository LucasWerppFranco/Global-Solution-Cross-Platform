# Diário de desenvolvimento: Território Vivo

Registro de cada etapa, com o que foi feito e a revisão aplicada. Referência: enunciado *CPAD - Global Solution 2026.2 - Territory Predictive Insights*.

> Código escrito primeiro e validado depois na imagem Docker do projeto (Etapa 11): `analyze` sem problemas, 24 testes passando e builds web e APK de release concluídos.

---

## Etapa 1: Base do projeto
- `pubspec.yaml` com 3 dependências (`provider`, `http`, `shared_preferences`) e mais `flutter_localizations` (SDK).
- `analysis_options.yaml` com `flutter_lints`, `avoid_print` e aspas simples.
- `.gitignore` do Flutter, mais IDE (`.idea`, `*.iml`) e `.env`.
- `AndroidManifest.xml` com a permissão **INTERNET**, obrigatória no APK de release para acessar a Open-Meteo, e o rótulo "Território Vivo".
- `core/theme.dart`: tokens `AppSpacing`, cores `AppColors` e `AppTheme.build(brightness, highContrast)` (claro, escuro e alto contraste).
- `core/format.dart`: números e datas no padrão pt-BR, sem depender do `intl`.
- `core/routes.dart`: nomes das rotas.

**Revisão:** o `flutter create` já tinha sido executado (`br.com.fiap.territorio_vivo`), e o manifesto reescrito usa o mesmo namespace/`MainActivity`.

## Etapa 2: Dados
- `data/territory.dart`: território (Sé/SP, coordenadas, população, 8 distritos) e **tabela de 8 indicadores** (`IndicatorSpec`), com limiar padrão, faixa válida, fonte, limitação, recomendação e público beneficiado.
- `data/models.dart`: `Panel`, `DataPoint`, `Indicator`, `TerritorySnapshot`, `Occurrence` (anônima), `AlertDecision` e a serialização JSON.
- `data/open_meteo_api.dart`: dados **reais**. Temperatura e chuva diárias (30 dias passados + 7 de previsão) e PM2.5 horário agregado em média diária. Separa histórico (antes de hoje) de previsão.
- `data/synthetic_api.dart`: séries sintéticas determinísticas por dia (tendência + sazonalidade semanal + ruído) e latência simulada.
- `data/local_store.dart`: persistência JSON (consentimento, preferências, ocorrências, decisões e cache). Leituras corrompidas são ignoradas.
- `data/territory_repository.dart`: rede → salva cache. Se a rede falhar → cache. Sem cache → erro. Inclui o "modo offline simulado".

**Revisão:** troquei o IIFE do gerador por um laço simples e limitei a semente a 31 bits, para os mesmos valores aparecerem no Web e no Android.

## Etapa 3: Domínio (Dart puro)
- `domain/alert_engine.dart`: regressão linear (inclinação, R²), estatísticas descritivas, projeção de 7 dias e o **motor de alertas** com 3 tipos (limiar, previsão oficial, tendência). Cada alerta traz evidências, confiança com justificativa, limitações e penalidades (cache, histórico curto).
- `domain/social_impact.dart`: **indicador de benefício social** (moradores potencialmente beneficiados por alertas revisados) e taxa de supervisão humana.
- `domain/validators.dart`: validações dos formulários, incluindo o **bloqueio de e-mail, telefone e CPF** na descrição.

**Revisão:** tipos numéricos explícitos (`0.0`, `.toDouble()` após `clamp`).

## Etapa 4: Estado global
- `SettingsState`: tema, alto contraste, fonte, limiares, modo offline e consentimento.
- `TerritoryState`: carregamento, erro e dados. A primeira carga mostra o *loading*; as atualizações mantêm os dados na tela.
- `OccurrencesState` e `DecisionsState`: listas persistidas.
- `watchAlerts(context)`: alertas **derivados** (dados + limiares), recalculados quando algum dos dois muda.

**Revisão:** `load()` não chama `notifyListeners()` de forma síncrona na primeira execução, o que evita o erro *setState during build* quando o provider é criado.

## Etapa 5: Componentes reutilizáveis (`core/widgets`)
- `state_views.dart`: `LoadingView`, `ErrorView`, `EmptyState`, `TerritoryBody` (carregamento/erro/dados com `AnimatedSwitcher`), `FreshnessBanner` (online/offline), `SectionTitle`, `ResponsiveGrid` e `BulletList`.
- `charts.dart`: `TrendChart` (`CustomPainter`: histórico, projeção tracejada, limiar e rótulo acessível), `ChartLegend` e `HorizontalBars`.
- `alert_widgets.dart`: `HumanDecisionBanner`, `SeverityChip`, `ConfidenceBadge` e `AlertTile`.
- `kpi_card.dart`: `KpiCard` e `StatTile`.

**Revisão:** tirei o `Hero` do `AlertTile`. As abas vivem num `IndexedStack`, então o mesmo alerta aparece em duas abas ao mesmo tempo e as tags repetidas quebrariam a transição.

## Etapa 6: App, rotas e telas de entrada
- `main.dart`: injeção de dependências (`MultiProvider`).
- `app.dart`: `MaterialApp` com temas, pt-BR, escala de fonte e a **tabela de rotas** (`AppRouter.generate`) com `arguments` tipados. `onGenerateInitialRoutes` impede voltar do consentimento para a home.
- Telas: `ConsentScreen`, `HomeShell` (4 abas) e `OverviewScreen` (impacto social, 3 painéis, alertas prioritários e pull-to-refresh).

## Etapa 7: Dashboards, indicador e alertas
- `DashboardScreen(panel)`: KPIs, mais um destaque próprio de cada painel:
  - **Clima**: cards de previsão dos próximos 7 dias (temperatura e chuva);
  - **Recursos**: consumo em % do limiar e projeção de 7 dias;
  - **Serviços**: ocorrências cidadãs por categoria (barras), com estado vazio e atalho para registrar.
- `IndicatorDetailScreen(id)`: gráfico com histórico + previsão/projeção + limiar, legenda, 6 estatísticas, fonte, limitações e alertas relacionados.
- `AlertsScreen`: filtros por severidade e "só pendentes" (estado local), com estados vazio, sem resultado e erro.
- `AlertDetailScreen(id)`: evidências, gráfico, confiança (barra + justificativa), limitações, sugestão, link para o indicador e **painel de decisão humana** (revisar/descartar com nota, ou desfazer).

## Etapa 8: Ocorrências, formulários e ajustes
- `OccurrencesScreen`: lista offline, exclusão por arrastar (com desfazer) e estado vazio.
- `OccurrenceFormScreen`: **formulário 1**, com categoria, distrito, data (até 30 dias atrás, sem datas futuras), descrição (10 a 500 caracteres, sem dados pessoais) e autorização obrigatória. Mostra erro por campo e um SnackBar.
- `ThresholdsScreen`: **formulário 2**, um limiar por indicador, com faixa válida, aceitando vírgula decimal e opção de restaurar os padrões. Ao salvar, os alertas são recalculados.
- `SettingsScreen`: tema (sistema/claro/escuro), alto contraste, tamanho do texto, limiares, simulação offline, termo e "apagar meus dados".

## Etapa 9: Testes
- `test/alert_engine_test.dart`: 12 testes (regressão, os 3 tipos de alerta, severidade, R² baixo, penalidades, ordenação e impacto social).
- `test/validators_test.dart`: descrição (incluindo dados pessoais), data, limiar e consentimento.
- `test/widget_test.dart`: aviso de decisão humana, `AlertTile` (texto e semântica) e `EmptyState`.

**Revisão:** cada expectativa foi calculada à mão (por exemplo, 1000 a 1130 com +10/dia cruza 1160 em 3 dias com R² = 1; a série alternada 900/1000 tem R² ≈ 0,015).

## Etapa 10: Documentação
- `README.md` nas 11 seções exigidas, na ordem do enunciado.
- `assets/logo.svg` (banner do cabeçalho).
- Este diário.

## Etapa 11: Imagem Docker própria e validação
- `docker/Dockerfile`: baseada em `ghcr.io/cirruslabs/flutter:3.44.0` (pública), com pré-aquecimento de Gradle, NDK 28.2 e artefatos web/android. Imagem `territorio-vivo-flutter`, independente de outros projetos.
- `scripts/flutter.sh`: constrói a imagem na 1ª execução (`--network host`, porque o `pub get` travou na rede bridge durante o build), usa volumes nomeados para os caches de pub e Gradle e devolve ao usuário do host a posse dos arquivos gerados.
- Resultados: `pub get` ✅ · `analyze` ✅ (2 sugestões de estilo corrigidas) · `test` ✅ 24/24 · `build web` ✅ · `build apk --release` ✅ (56 MB).

## Etapa 12: Auditoria contra o PDF e teste de fumaça
- `test/app_smoke_test.dart`: abre o app completo com a API simulada (`MockClient`) e percorre consentimento, as 4 abas, os 3 painéis, os indicadores, um alerta, os formulários e o termo, em **4 combinações**: celular 390×844, tablet 1024×1366 com fonte 200%, celular 360×740 com fonte 200% e tema escuro de alto contraste, e o estado de erro sem conexão e sem cache. Também testa o formulário: erros, bloqueio de telefone e envio.
- **Bugs reais encontrados e corrigidos:**
  - overflow na linha "N indicadores · M alertas" do card de painel com fonte grande;
  - overflow nos selos de confiança e de severidade com fonte grande;
  - o SnackBar flutuante cobria o botão de envio nos formulários (adicionei espaço no fim da lista).
- Código morto removido: `AppSpacing.xl`, `ChartLegend.showProjection`, o parâmetro `now` de `SyntheticApi.fetch` e a mensagem configurável do `LoadingView`.
- `appWithState()` em `app.dart`: a mesma montagem de estado é usada por `main` e pelos testes.
- Resultado: `analyze` sem problemas e **29/29 testes passando**.

## Etapa 13: Animações com propósito
Todas usam só o SDK e ficam instantâneas quando o sistema pede para reduzir movimento (`AppMotion.of`).
1. **Contador do benefício social**: o número sobe ao revisar um alerta e mostra o efeito da decisão humana.
2. **Gráfico se desenhando**: o histórico aparece da esquerda para a direita e depois a projeção tracejada, separando o observado do previsto.
3. **Barras preenchendo** (`AnimatedBar`): confiança, consumo em relação ao limiar, ocorrências e supervisão humana.
4. **Pulso no alerta crítico**: 3 pulsos e para, chamando atenção para a prioridade sem animar indefinidamente (há teste garantindo que termina).
6. **Transição "para frente"** (`FadeForwardsPageTransitionsBuilder`) entre as telas, indicando descida na hierarquia.

Resultado: `analyze` sem problemas e 29/29 testes passando.

---

## Conferência com o checklist do enunciado

| Item | Status | Onde |
|---|---|---|
| ≥ 5 telas com fluxo coerente | ✅ 12 telas | `features/` |
| Rotas nomeadas + parâmetros | ✅ | `core/routes.dart`, `app.dart` |
| ≥ 3 dashboards com gráficos/indicadores, histórico e tendência | ✅ | `dashboard_screen.dart`, `kpi_card.dart`, `charts.dart` |
| Alertas com justificativa, confiança e limitações | ✅ | `alert_engine.dart`, `alert_detail_screen.dart` |
| Aviso de decisão humana | ✅ | `HumanDecisionBanner` (Visão geral, Alertas, Detalhe, Consentimento) |
| Estado global em ≥ 2 telas | ✅ | `state/` |
| Carregamento / erro / vazio | ✅ | `TerritoryBody`, `EmptyState` |
| API (real ou simulada) | ✅ ambas | `open_meteo_api.dart`, `synthetic_api.dart` |
| Persistência local | ✅ | `local_store.dart` |
| Útil sem conexão | ✅ | `territory_repository.dart`, `FreshnessBanner` |
| Formulário com validação | ✅ 2 formulários | `occurrence_form_screen.dart`, `thresholds_screen.dart` |
| Indicador de benefício social | ✅ | `social_impact.dart`, `OverviewScreen` |
| Tema e componentes reutilizáveis | ✅ | `core/` |
| Contraste e fonte ampliada | ✅ | `theme.dart`, `SettingsScreen` |
| Descrições para leitor de tela | ✅ | `Semantics` em cards, gráficos e alertas |
| Anonimização + consentimento | ✅ | `Occurrence`, `ConsentScreen`, `Validators.description` |
| Layout em 2 tamanhos | ✅ celular e tablet, também com fonte 200% | `test/app_smoke_test.dart` |
| Sem código morto/print/imports não usados | ✅ `flutter analyze`: No issues found | |
| App roda sem erros | ✅ build web/APK e percurso completo sem exceções | `test/app_smoke_test.dart`; conferir visualmente |
| Prints de todas as telas no README | ⏳ capturar | `assets/screenshots/` |
| Vídeo ≤ 3 min | ⏳ gravar | |
| APK em Releases | ⏳ gerado (`build/app/outputs/flutter-apk/app-release.apk`, 56 MB), falta publicar | |

**Bônus implementados (baixo custo):** dados reais (Open-Meteo), temas escuro e alto contraste, testes automatizados, animações com propósito (transição carregando → dados) e APK de release (falta gerar).
**Bônus não implementados:** mapa, notificações e IA generativa, por exigirem dependências ou chaves e terem custo maior.

---

## Próximos passos (time)

```bash
./scripts/flutter.sh pub get
./scripts/flutter.sh analyze        # esperado: sem erros; corrigir qualquer aviso
./scripts/flutter.sh test           # esperado: todos passando
DOCKER_ARGS="-p 8080:8080" ./scripts/flutter.sh run -d web-server --web-hostname 0.0.0.0 --web-port 8080
./scripts/flutter.sh build apk --release
```

**Ponto de atenção na compilação:** `DropdownButtonFormField(initialValue: …)` é a API atual do Flutter ≥ 3.35. Se o `analyze` acusar erro nela, troque por `value:`.

Depois: capturar os prints com os nomes da tabela do README (seção 4), gravar o vídeo, publicar o APK em *Releases*, preencher o link do vídeo no README e no `Entrega.txt` e fazer os commits.

### Roteiro sugerido para o vídeo (3 min)
| Tempo | Cena |
|---|---|
| 0:00 | Problema e público (Visão geral) |
| 0:20 | Consentimento (apagar dados em Ajustes para mostrar) |
| 0:35 | Painéis Clima, Recursos e Serviços (KPIs, previsão, projeção) |
| 1:15 | Detalhe do indicador (gráfico, estatísticas) |
| 1:30 | **Gerar um alerta:** Ajustes › Limiares › baixar a temperatura para 25 °C › salvar › abrir o alerta (evidências, confiança, limitações, aviso humano) › marcar como revisado › impacto social sobe |
| 2:10 | Formulário de ocorrência: erros (descrição curta, telefone na descrição) › envio › aparece no painel Serviços |
| 2:35 | Simular offline (aviso, confiança reduzida) · tema escuro/alto contraste · fonte 200% |
