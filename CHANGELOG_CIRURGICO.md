# Changelog cirúrgico

Base única: `eu1995`, blob `a764baec7f716ad893ee82ae807d91e2c45f3986`, igual integralmente a `Bf/main:1995`. A especificação e o original não foram modificados. A leitura integral do original foi distribuída entre três agentes por segmentos contíguos; a especificação foi lida integralmente antes da edição.

## Commits separados

1. `ed757f5` — nova `RemoraScalper1995_Weis1996.mq5`, remoção POC/C1 antigo, núcleo Weis literal, adaptador e telemetria. O marcador financeiro permanecia original neste commit.
2. `3d2cd5d` — correção exclusiva na função do marcador: `written==25` para `written==27`, com teste e relatório próprios. Não altera literal, flags, flush, presença de obrigação ou liberação financeira.
3. Entrega de testes, relatórios finais e diff de revisão em commit posterior.

## Mapa de mudanças

| Área | Mudança e motivo |
|---|---|
| Arquivo original | Preservado byte a byte; toda candidata está em arquivo novo |
| POC | Removidos enum/struct/inputs/cálculos/janelas/classificações/consumidores exclusivos; POC_REMOVAL_MAP detalha destinos |
| C1 | OMClassify verificado fornece esforço, progresso, eficiência por eventos e rejeição; candle-dir CONT permanece; nenhum fallback permissivo |
| Kernel | Extração literal de OMBands estrutural inerte, OMNumber e funções de ondas/classificação; nenhuma banda/localização/sigma da1.996 usada |
| Dados | Incremental por CopyTicksRange, com origem diária, lotes limitados, fonte de volume única, controle de multiplicidade/fronteira e snapshot fechado causal |
| Stage2/guard final | Mesmos limiares de esforço vivo/direção na entrada, sobre ondas de negócios; ABS tentativa congelada é distinta da reação viva. Nenhum timeout/trigger renovado |
| Macro e C2–C5 | Fórmulas intactas; diagnósticos distinguem bloqueio real, mismatch observado e indisponibilidade |
| Telemetria | IDs candidato→ARMED→request→deal, fila separada limitada, resultados reais e perdas explícitas; sem FileFlush por evento no stream antigo |
| Envio | Duas chamadas LLRecord em memória; protocolo operacional/financeiro restante literal |
| CSV histórico | Cabeçalhos e aridade preservados; métricas POC/candle-wave aposentadas vazias, sem estado fictício |
| Inputs |70 originais intactos +7 numéricos da referência, menos3 POC. MaxBody legado retido/inativo em C1 |
| Compilação/replay | Não realizados; status e limitações explícitos |

## Diff completo

`reports/SCALPER1995_FULL.diff` contém a comparação integral do original com a candidata final e a adição dos três includes. É um artefato de revisão, não instrução para sobrescrever o original. O diff real da branch adiciona o fonte novo; o original não recebe patch. `patches/economic-marker-length.patch` reproduz somente a correção financeira sobre a candidata pré-correção.

Preservados e conferidos: VWAP vigente/viva/D‑1, sigma, bandas/multiplicadores, M5/M1, C2–C5, BASE/TURBO, macro, FAR, close congelado/região ABS legacy, margem/overshoot/timeout, exposição, sizing, stops, margem financeira, FOK, ownership, request journals, BE/progressão, EOD, recuperação e contabilidade. Prova literal não é equivalência global de operações; ver REGRESSION_STRATEGY e REGRESSION_FINANCE.

## Riscos restantes

- Compilação nativa, execução MT5 e regressão financeira dinâmica pendentes.
- Completude do histórico retornado pelo broker não pode ser provada apenas por CopyTicksRange; revisões fora da fronteira lida não são auditadas integralmente.
- Controle de lotes/CPU é posterior à chamada; broker pode alocar/demorar antes de retornar. Catchup desde meia-noite pode atrasar prontidão inicial.
- Fragmentação no extremo pode alterar peakVolume ABS por propriedade da referência, preservada em vez de inventar outro motor.
- Telemetria pode perder eventos em crash/overflow/falha de disco; perdas conhecidas são explícitas e não substituem autoridade financeira.

## Revisão dirigida da entrega-base85be544

A única correção operacional adicional é o encerramento definitivo por epoch alterado: novo helper `EndRevisedWeisThesis` e chamadas no início de ProcessArmedSignal e após o serviço Weis no tick/timer. A espera transitória conserva o mesmo epoch. Não há alteração em includes, inputs, C1, VWAP, sigma, macro, sizing, execução, journals, BE, EOD ou FAR. O helper usa o reset ARMED/FAR já existente, sem limpar obrigações financeiras. O diff contra a entrega-base está em `reports/SCALPER1995_REVIEW.diff`. MaxBody recebeu documentação e teste da perda funcional, sem novo filtro.
