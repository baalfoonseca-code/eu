# Mapa de remoção POC

Inventário iniciado antes da edição e confrontado estaticamente com `RemoraScalper1995_Weis1996.mq5` e seus includes operacionais. Cada ocorrência textual da busca baseline está em `tests/fixtures/poc_references_original.json`; as linhas desta tabela referem-se ao original. Os destinos abaixo descrevem a candidata implementada; os testes/diff qualificam a evidência.

| Referências originais | Consumidores | Destino na candidata |
|---|---|---|
| `ENUM_POC_STATE` 76–82 e `PocStateStr` 1296–1306 | Snapshot, classificação, CSV, log de conflito | Enum/conversor removidos; conflito real da matriz permanece. |
| Inputs `Inp_POC_WindowSec`, `Inp_POC_FollowRatio`, `Inp_RejectPOCTies` 162–164 | Janelas, razão following, ablação ties, init, CSV config | Inputs e validações/prints exclusivos removidos; nenhuma condição foi substituída por true. |
| `POCResult` 234–249; `ResetPOCResult` 1560–1568 | Cálculo POC, snapshot, CSV | Estrutura/reset removidos. Volumes agressor POC ficam vazios no CSV; FAR mantém aquisição própria. |
| `pocNow`, `pocPrev`, `windowsValid`, `priceMove`, `pocMove` 269–271 | Comparação de duas janelas e CSV | Campos removidos; células CSV vazias. `priceMove` destas janelas não foi reutilizado como trajetória da onda nova. |
| `displacementOk`, `moveDir`, `pocState`, `contDisplacementOk`, `contMoveDir`, `contPocState` 272–277 | C1 e telemetria | Substituídos por evidência Weis causal; mínimos de deslocamento existentes preservados e aplicados à onda, sem janela POC. |
| `absDivergence`, `absStallStrict`, `absFollowingReaction`, `absFollowingExtension`, `absPocContextOk` 290–291 | C1 ABS, CSV, log ABS_FOLLOWING_EXTENSION | Contexto POC removido; colunas legadas vazias. ABS passa a esforço congelado no extremo, baixa eficiência e rejeição. |
| `cont_poc_ok` 293 | C1 CONT e CSV | Campo removido; CONT passa a esforço, eficiência, progresso, direção e drawdown da referência. |
| `ComputePOCWithTieCore` 1723–1805; wrapper 1814–1820 | Duas consultas de tick por matriz | Ambas as funções removidas, sem consultas de janelas POC. |
| Bloco POC de `ComputeMatrixSnapshot` 2177–2237 | Janelas adjacentes causais; contexto ABS/CONT | Cálculos exclusivos removidos; C2/C3/C4/C5 preservados. |
| C1 ABS 2254–2276; CONT 2278–2290 | Aprovação de C1 | Evidência incompatível substituída; candle direction CONT permanece adicional. Constantes permissivas não substituem evidência. |
| `perfPOC` 1004, 1818, 3965, 4170, 4406–4407 | Medição e prints de custo | Medidor morto removido; nova Weis mantém medição própria. |
| `CsvConfigHeader/Row` 2649/2660 | Coluna REJECT_POC_TIES | Header preservado; célula vazia por compatibilidade histórica, sem input ou função decisória. |
| `CsvMatrixHeader/Row` 2748–2810/2887–2974 | Windows, estados POC, top1/top2, volumes, razão/resposta | Headers preservados/células POC vazias; evidência Weis no lifecycle analítico próprio. CSV Trades e journals mantidos. |
| Log `ABS_FOLLOWING_EXTENSION_BLOCK` 3499–3501; estado POC no conflito 3506 | Prints | Diagnóstico obsoleto retirado; ROUTE_CONFLICT_BLOCK e sua condição mantidos. |
| `Validate1995Inputs` 4006/4022; prints OnInit 4214–4220 | Sanidade/print do motor antigo | Trechos POC removidos; WWValidateInputs valida somente parâmetros próprios do motor novo. |

## Campos compartilhados preservados

`regionHigh`, `regionLow`, `regionEndTime`, `Inp_Region_Candles` e `ComputeTrigger` não são exclusivamente POC: são referência do FAR e do modo ABS legacy. Preservá-los. `CopyTradeTicksStrict` também atende VWAP e FAR; remover suas chamadas POC não autoriza remover helper compartilhado. C1 novo não pode modificar VWAP, sigma, C2/C3/C4/C5 ou os gates financeiros.

## Dependências Weis antigas a substituir em conjunto

- `RebuildWeisCache` (1822), `ComputeLiveWaveO1` (1879), campos `ww*` de cache e snapshot.
- `EntryDispatchGuard` (1486–1489): último veto Weis antes da preparação financeira.
- `ProcessArmedSignal` (3733–3737): onda viva no Stage 2.
- Bootstrap (4072), fechamento M1 (4318), observação read-only (4260), hard contradiction (4324) e gate de novas matrizes (4359).

A proteção EOD/BE/reconciliação deve continuar executando antes dos gates analíticos. Ausência de baseline não fabrica confirmação e não elimina obrigações financeiras.

## Resultado da inspeção da candidata

- Removidos: `ENUM_POC_STATE`, `POCResult`, `PocStateStr`, `ResetPOCResult`, `ComputePOCWithTieCore`, `ComputePOCWithTie`, os três inputs POC e os campos operacionais exclusivamente dependentes de suas janelas.
- Substituídos: cache Weis M1 e C1 por `Weis1996Kernel.mqh`/`Weis1996Engine.mqh`. Stage 2 e guard final usam evidência da nova aquisição; não reintroduzem janelas POC.
- Compatibilidade histórica: os headers originais de Audit/Shadow, incluindo `REJECT_POC_TIES`, estados, janelas e métricas POC, permanecem com células vazias explicitamente marcadas `retired legacy metric` ou `schema compatibility only`. Não são variáveis nem booleanos permissivos e não são lidos por C1. CSV Trades e journals preservam seu esquema financeiro.
- Comentários herdados de seções POC podem permanecer no arquivo derivado sem código ativo abaixo. A referência completa vendorizada em `references/` é prova de origem e não é incluída pelo EA.
- Região/FAR e `CopyTradeTicksStrict` permanecem compartilhados e operacionais para suas funções anteriores.

Esta inspeção estática demonstra os destinos textuais e a separação dos campos legados. Compilação, execução de mercado, replay e performance nativa continuam com status próprio em `TEST_RESULTS.md`; não são inferidos pela busca de símbolos.
