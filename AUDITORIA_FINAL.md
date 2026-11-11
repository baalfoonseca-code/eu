# Auditoria crítica independente da reconstrução

Auditoria realizada por agente separado da implementação, em 11/11/2026. Foram lidos o diff completo de `eu1995` para `RemoraScalper1995_Weis1996.mq5` (1.237 linhas na primeira fotografia auditada), os três includes operacionais e os pontos de integração. Mudanças posteriores motivadas pelos achados foram conferidas nos trechos afetados e nos testes correspondentes. Não houve edição de código pela auditoria.

## Achados que refutaram a primeira candidata

| Gravidade | Achado reproduzível | Correção/conferência |
|---|---|---|
| P1 — escopo e disponibilidade | O primeiro adapter usava `D1_SESSION_START` e `D1_SESSION_END_*` para limitar a coleta Weis a 09:00–18:25/18:30. Essas constantes eram somente janelas do cálculo D-1 na original. Configurações válidas de entrada antes de 09:00 ou depois de 18:25 ficavam bloqueadas pela nova inteligência. | Origem do replay alterada para meia-noite do calendário do broker, sem teto D-1; entrada continua governada pelos horários originais. Testes `before09_trade_collection_not_gated_by_D1_schedule` e `after1825_trade_collection_not_capped_by_D1_schedule` executados e aprovados no harness do adapter. A refutação inicial foi por inspeção e contracaso de configuração, não por alegação de execução MT5. |
| P2 — semântica do diagnóstico | O primeiro evento `MACRO_DIRECTION_BLOCK` também era emitido com gate macro desligado. Era discordância observada, não bloqueio efetivo. | Rótulo corrigido para `MACRO_DIRECTION_MISMATCH_OBSERVED` quando o gate está desligado. Predicado operacional preservado. |
| P2 — ponto cego de indisponibilidade | O gate anterior à matriz retornava por macro indisponível sem evento que explicasse a ausência de avaliação M1. | Adicionado `ObserveMatrixUnavailable` com `SIGNAL_EVALUATION_SKIPPED` e encerramento analítico; não altera clocks, não arma e não remove o gate. Motivos D-1/VWAP/Weis também registrados nesse caminho. |
| P2 — motivo de evidência congelada | Epoch inválida era corretamente impedida de enviar, mas o motivo genérico podia dizer `LIVE_WEIS_UNAVAILABLE_WEIS_READY`, escondendo a invalidação da evidência congelada. | Corrigido observacionalmente: o guard final registra `FROZEN_WEIS_EVIDENCE_REVISED`; Stage 2 emite `THESIS_INVALIDATED` com esse motivo, mantendo espera e timeout/trigger existentes. Trechos finais conferidos pela auditoria; não foi introduzido reset estratégico novo. |
| Defeito financeiro preexistente | O literal `S1995_ECONOMIC_OBLIGATION\r\n` tem 27 bytes ASCII, enquanto a original compara retorno com 25. Com primeira escrita completa e flush bem-sucedido, a função original retorna falha; uma tentativa posterior pode entrar por `FileIsExist`. | Harness portável refuta a função original e verifica correção mínima 25→27, short write, falha de open/flush, sentinel e reinício. Correção isolada aplicada no commit `3d2cd5d`; conferida em `REGRESSION_FINANCE.md` e no log final com 8/8 testes financeiros aprovados. API de arquivo MT5 e reinício nativo não foram exercitados. |

## Pontos de integração conferidos

- POC operacional retirada: estruturas, funções, inputs e consumidores exclusivos não participam de C1 nem da revalidação. Headers históricos retidos recebem células vazias; não são variáveis fictícias permissivas.
- Kernel Weis extraído da referência verificada, incluindo baseline de ondas fechadas, congelamento no extremo, eventPath e condição CONT `drawdown < eventStep`. Não foi importado o motor de bandas/sigma/posição da 1.996.
- Há guardas do motor novo tanto no Stage 2 quanto no guard final antes do envio. O ARMED mantém evidência de Stage 1 e epoch congeladas; revalidação utiliza direção/esforço da onda ativa, sem reutilizar o volume da tentativa ABS como se fosse volume da reação.
- Mudança da classificação viva, isoladamente, não cria política completa de invalidação 1.996. Timeout e trigger permanecem os originais; nenhuma prioridade arbitrária foi acrescentada ao conflito.
- Gestão financeira, EOD e BE continuam precedendo o serviço analítico no OnTick. Falha/ausência Weis não impede essas rotinas.
- Inputs retidos conservam tipo/default/ordem relativa. Os mínimos de deslocamento mantêm unidade, mas passam da comparação entre janelas POC ao progresso de onda: diferença semântica explícita.
- Lote do ARMED aparece como não calculado; tentativa, aceitação e fill são eventos distintos. Filas/contadores de perda não fabricam desfechos quando a observação é incompleta.

## Execução dos testes e conferência final

Comando executado independentemente pela auditoria: `python3 tests/run_all.py` em `/workspace/eu`. A primeira execução foi anterior ao commit financeiro e encontrou a divergência esperada 25/27. A reexecução final pelo agente principal está registrada em `reports/validation.log`, cujo término e resultados foram conferidos pela auditoria.

| Camada | Resultado dessa execução |
|---|---|
| Kernel literal e casos numéricos | 25/25 aprovados, mais conferência literal da referência. |
| Adapter com serviços do broker simulados | 23/23 aprovados. |
| Lifecycle analítico | 2/2 aprovados, incluindo harness da fila e I/O simulado. |
| Preservação estática | 13/13 aprovados. |
| Marcador econômico | 7/8 na execução anterior ao patch; o único FAIL exigia 27 na candidata ainda com 25. Após aplicação isolada, reexecução final registrada: 8/8 aprovados. |

A falha anterior foi reportada e preservada no histórico da auditoria. O log final registra **71 testes aprovados** (25 kernel + 23 adapter + 2 lifecycle + 13 preservação + 8 financeiro), além da conferência literal do kernel. Os casos do harness refutam comportamentos delimitados; não demonstram rentabilidade nem reproduzem integralmente o broker, event queue e persistência MT5.

## Limitações residuais e aceite

`COMPILACAO_NATIVA_NAO_VERIFICADA` — não há log nativo MetaEditor nem relação de warnings reais. Harness C++ e inspeção de símbolos/tipos não substituem o compilador MQL5.

`REPLAY_NAO_VERIFICADO` — não há replay real de WIN/WDO ou backtest MT5, comparação financeira fora da amostra, distribuição empírica de latência ou logs reais de intenções/fills produzidos por esta candidata. Exemplos sintéticos devem continuar identificados como sintéticos.

A recuperação de histórico valida ordem, multiplicidade e fronteiras observáveis, mas não prova que o broker entregou todos os negócios ou que não revisou um trecho anterior que deixou de ser consultado. Uma chamada `CopyTicksRange` pode bloquear além do orçamento de CPU suave. Custo p95/p99 instrumentado não é um budget preemptivo nem medição de bolsa.

A sessão Weis agora é o dia do calendário do broker por coerência com o reset diário existente. Isso muda a formação de ondas em relação ao cache M1 original e não representa promessa de sinais equivalentes. Os efeitos em candidatos, conflitos, bloqueios, aceitação e fills exigem comparação com dados apropriados.

Sem outros achados P1 novos demonstrados nesta revisão. A ausência de outro achado não comprova ausência de defeitos. A candidata permanece experimental, com aceite nativo e operacional pendente; não homologada para produção.
