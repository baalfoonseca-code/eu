# Regressão da estratégia — reconstrução 1.995 / Weis 1.996

A candidata é `RemoraScalper1995_Weis1996.mq5`, derivada exclusivamente de `eu1995`. A original e a especificação permanecem preservadas. Os testes abaixo comparam o texto executável das regiões protegidas; não executam o robô em MetaTrader e não demonstram equivalência financeira em mercado.

## Provas estáticas executadas

Comando: `python3 tests/test_preservation.py` na raiz do repositório. Resultado final desta auditoria: **13 testes aprovados, 0 falhas, 0 skips**.

| Área | Prova | Resultado observado |
|---|---|---|
| Integridade | SHA-256 integral de `eu1995` e da especificação contra identidades registradas | APROVADO |
| Inputs herdados | Os 73 inputs originais, menos os 3 exclusivamente POC, preservam nome, tipo, ordem relativa e default | APROVADO: 70 herdados |
| Novos inputs | Exatamente os 7 defaults Weis verificados; ausência da arquitetura de bandas/localização/sessão 1.996 | APROVADO: 77 inputs no total |
| VWAP vigente/viva/D-1 | `ResetVwapCache`, `UpdateVwapIncremental`, `GetLiveVwapSnapshot`, `TryCalcD1` literais | APROVADO |
| Sigma histórico | `CalcSigmaHistory` literal | APROVADO |
| Macro | `ComputeMacroContext` literal; o padrão continua M5 | APROVADO |
| C2/C3/C4/C5 | Trecho inicial integral de `ComputeMatrixSnapshot`, até o início da substituição C1 | APROVADO |
| BASE/TURBO e macrofiltro | Trecho desde BASE/TURBO até o retorno da matriz literal | APROVADO |
| Contradição forte | `HasHardDirectionalContradiction` literal | APROVADO |
| FAR | As 13 funções prefixadas `FAR` são literais, incluindo contexto, flags e decisão | APROVADO |
| Trigger/confirmação | 11 funções de grade, timeout, close congelado, negócio real, confirmação, despacho e trigger literais | APROVADO |
| Protocolo financeiro | 199 funções da zona BE até o final, sizing/exposição/EOD/envio e CSV financeiro; exceções exatas: correção isolada `written==25` → `written==27` e duas chamadas de telemetria em memória no envio | APROVADO |
| CSV histórico | Os 6 grupos `Csv*Header` permanecem literais e cada linha conserva o número de colunas do grupo | APROVADO |
| Remoção operacional | Nenhum identificador antigo de POC ou Weis por candle permanece no código executável da candidata | APROVADO |
| Ordem financeira | Sync/accounting, MAE/MFE, EOD e BE precedem `WWService`; timer reconcilia finanças antes do motor | APROVADO |
| Causalidade do cache | Catch-up não emite sinal passado; consulta e lote terminam em `endExclusive-1`; snapshot antes do próximo lote e limitado à última barra fechada | APROVADO estático |
| Estrutura básica | Delimitadores balanceados; consumidores `s.*` da matriz/reset/CSV referem campos declarados | APROVADO; não é typecheck MQL |

Os grupos CSV têm respectivamente 6, 10, 116, 14, 19 e 46 colunas. Colunas aposentadas de POC/ondas por candle permanecem apenas como esquema histórico e são emitidas vazias; nenhuma variável POC fictícia permanece para preenchê-las. A estrutura histórica não comprova que qualquer linha real tenha sido produzida nesta máquina.

## Mudanças autorizadas e fronteiras

- C1 passa a consumir a classificação do kernel numérico verificado, usando snapshot de negócios anterior ao fechamento M1. Direção, esforço, progresso, eficiência e rejeição passam a se referir à onda de negócios, em vez das antigas janelas POC e ondas de candles. Os sinais podem mudar por definição.
- O filtro de direção do candle CONT permanece adicional ao novo C1; C2/C3/C4/C5, BASE/TURBO e filtro macro continuam nas mesmas fórmulas.
- Stage 2 e o guard de despacho passam a consultar a onda viva incremental. O requisito original de direção na direção da entrada e esforço mínimo de rompimento permanece; não é substituído por `true` nem pela classificação C1 congelada. Em ABS, a tentativa rejeitada e a reação viva são evidências distintas.
- Regiões de candles fechados continuam necessárias para FAR e trigger ABS legacy; não são removidas junto da POC.
- A nova análise não antecede `SyncAccountingState`, EOD e BE no `OnTick`. Falta de baseline ou histórico não deve liberar entrada nem impedir a proteção de posição já aberta.
- Conflito interno do classificador Weis é diferente de conflito final de rotas. `ROUTE_CONFLICT_BLOCK` permanece e nenhuma prioridade ABS/CONT foi acrescentada.

Em `SendOrder`, somente as duas chamadas exatas `LLRecord` de SEND_ATTEMPT e resultado síncrono são retiradas antes da comparação; qualquer outra edição continua reprovando o teste. O evento de resultado distingue rejeição final pelo predicado financeiro original `IsFinalRejectedRetcode`; nenhum retcode é convertido em fill. Essas chamadas enfileiram observações em memória, não alteram os predicados financeiros.

As verificações literais provam ausência de edição nas funções e blocos comparados, não igualdade global das trajetórias de operações. Alterar C1 muda posições, horários e estado futuro, inclusive as oportunidades vistas pelos subsistemas preservados.

## Limitações e testes pendentes

`COMPILACAO_NATIVA_NAO_VERIFICADA` — MetaEditor/MT5 ausentes nesta máquina. A verificação lexical não detecta todos os erros de tipos, overloads ou APIs MQL5.

`REPLAY_NAO_VERIFICADO` — não há replay real WIN/WDO, feed do broker nem sessão de Strategy Tester. Não foram medidos os totais comparativos de candidatos, bloqueios C2–C5, macro, FAR, ARMED, triggers, pedidos, fills, PnL, R, drawdown, p95/p99 de execução ou desempenho fora da amostra. Nenhum número foi fabricado.

Permanecem necessárias provas com mesmos dados para VWAP/sigma/macro, rota, Stage 2, timeout, overshoot, FAR e casos financeiros reais, além dos testes determinísticos do kernel/ingestão entregues em arquivos separados. A compilação, quando executada, também não homologará a estratégia nem comprovará rentabilidade.
