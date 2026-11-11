# Inputs — comparação efetiva da reconstrução

Comparação estática executada sobre `eu1995`, `RemoraScalper1995_Weis1996.mq5` e `include/Weis1996Engine.mqh`. Baseline: **73** inputs. Candidata: **77** inputs efetivos (70 originais preservados + 7 da referência). As inclusões não duplicam inputs. Nenhum arquivo `.set` foi fornecido.

Resultado: os **70 inputs retidos conservam nome, tipo, default e ordem relativa**; nenhuma alteração de default foi detectada. Os sete defaults novos coincidem com `references/ObjectiveMatrix.e0bacb9.mqh`. Isto é evidência estática de declarações, não equivalência de sinais nem prova de execução MT5.

## Lista completa dos inputs originais

| # | Input | Tipo | Default original | Destino efetivo |
|---|---|---|---|---|
| 1 | `Inp_Magic_WIN` | `int` | `60001` | Preservado, mesmo tipo/default. |
| 2 | `Inp_Magic_WDO` | `int` | `60002` | Preservado, mesmo tipo/default. |
| 3 | `CSVFileName` | `string` | `"Scalper1995"` | Preservado, mesmo tipo/default. |
| 4 | `BacktestStart` | `datetime` | `D'2025.01.01'` | Preservado, mesmo tipo/default. |
| 5 | `Inp_ContextTF` | `ENUM_TIMEFRAMES` | `PERIOD_M5` | Preservado, mesmo tipo/default. |
| 6 | `Inp_SignalTF` | `ENUM_TIMEFRAMES` | `PERIOD_M1` | Preservado, mesmo tipo/default. |
| 7 | `Inp_StartHHMM` | `int` | `900` | Preservado, mesmo tipo/default. |
| 8 | `Inp_StopEntryHHMM` | `int` | `1530` | Preservado, mesmo tipo/default. |
| 9 | `Inp_EOD_CloseHHMM` | `int` | `1750` | Preservado, mesmo tipo/default. |
| 10 | `Inp_SizingMode` | `SIZING_MODE` | `SIZING_FIXED` | Preservado, mesmo tipo/default. |
| 11 | `Inp_FixedLots` | `double` | `1.0` | Preservado, mesmo tipo/default. |
| 12 | `Inp_RiskPerTradePct` | `double` | `0.15` | Preservado, mesmo tipo/default. |
| 13 | `Inp_MaxLots` | `double` | `2.0` | Preservado, mesmo tipo/default. |
| 14 | `Inp_SL_Pts_WIN` | `double` | `400.0` | Preservado, mesmo tipo/default. |
| 15 | `Inp_TP_Pts_WIN` | `double` | `2000.0` | Preservado, mesmo tipo/default. |
| 16 | `Inp_SL_Pts_WDO` | `double` | `10.0` | Preservado, mesmo tipo/default. |
| 17 | `Inp_TP_Pts_WDO` | `double` | `25.0` | Preservado, mesmo tipo/default. |
| 18 | `Inp_SpreadMaxPts_WIN` | `double` | `30.0` | Preservado, mesmo tipo/default. |
| 19 | `Inp_SpreadMaxPts_WDO` | `double` | `2.0` | Preservado, mesmo tipo/default. |
| 20 | `Inp_EnableBreakEven` | `bool` | `true` | Preservado, mesmo tipo/default. |
| 21 | `Inp_EnableDailyRiskStop` | `bool` | `true` | Preservado, mesmo tipo/default. |
| 22 | `Inp_MaxDailyLossR` | `double` | `3.0` | Preservado, mesmo tipo/default. |
| 23 | `Inp_EnableConsecutiveLossStop` | `bool` | `true` | Preservado, mesmo tipo/default. |
| 24 | `Inp_MaxConsecutiveLosses` | `int` | `3` | Preservado, mesmo tipo/default. |
| 25 | `Inp_MaxTradesDay` | `int` | `10` | Preservado, mesmo tipo/default. |
| 26 | `Inp_CooldownSec` | `int` | `0` | Preservado, mesmo tipo/default. |
| 27 | `Inp_LossCooldownSec` | `int` | `0` | Preservado, mesmo tipo/default. |
| 28 | `Inp_ArmedTimeoutSec` | `int` | `300` | Preservado, mesmo tipo/default. |
| 29 | `Inp_ABSTriggerReference` | `ABS_TRIGGER_REFERENCE` | `ABS_TRIGGER_SIGNAL_CLOSE` | Preservado, mesmo tipo/default. |
| 30 | `Inp_Region_Candles` | `int` | `2` | Preservado, mesmo tipo/default. |
| 31 | `Inp_BreakoutMargin_WIN` | `double` | `175.0` | Preservado, mesmo tipo/default. |
| 32 | `Inp_BreakoutMargin_WDO` | `double` | `3.5` | Preservado, mesmo tipo/default. |
| 33 | `Inp_MaxOvershoot_WIN` | `double` | `100.0` | Preservado, mesmo tipo/default. |
| 34 | `Inp_MaxOvershoot_WDO` | `double` | `2.5` | Preservado, mesmo tipo/default. |
| 35 | `Inp_ABS_Effort` | `double` | `1.50` | Preservado; esforço de C1 usa baseline fechado das ondas por negócios, não candles M1. |
| 36 | `Inp_CONT_Effort` | `double` | `1.50` | Preservado; esforço de C1 usa baseline fechado das ondas por negócios, não candles M1. |
| 37 | `Inp_ABS_BreakoutEffort` | `double` | `1.50` | Preservado; Stage 2 exige direção/esforço da onda ativa por negócios. |
| 38 | `Inp_CONT_BreakoutEffort` | `double` | `1.50` | Preservado; Stage 2 exige direção/esforço da onda ativa por negócios. |
| 39 | `Inp_POC_WindowSec` | `int` | `300` | Removido: exclusivo do motor POC. |
| 40 | `Inp_POC_FollowRatio` | `double` | `0.40` | Removido: exclusivo do motor POC. |
| 41 | `Inp_RejectPOCTies` | `bool` | `false` | Removido: exclusivo do motor POC. |
| 42 | `Inp_ABS_MinPriceMovePts_WIN` | `double` | `60.0` | Preservado; mínimo na mesma unidade de preço aplicado a progresso da onda, sem janela POC. |
| 43 | `Inp_ABS_MaxBodyPts_WIN` | `double` | `60.0` | Retido por compatibilidade; não exerce gate C1. Era usado só em stall POC removido; continua validado como positivo no init. |
| 44 | `Inp_ABS_MinPriceMovePts_WDO` | `double` | `2.0` | Preservado; mínimo na mesma unidade de preço aplicado a progresso da onda, sem janela POC. |
| 45 | `Inp_ABS_MaxBodyPts_WDO` | `double` | `2.0` | Retido por compatibilidade; não exerce gate C1. Era usado só em stall POC removido; continua validado como positivo no init. |
| 46 | `Inp_CONT_MinPriceMovePts_WIN` | `double` | `50.0` | Preservado; mínimo na mesma unidade de preço aplicado a progresso da onda, sem janela POC. |
| 47 | `Inp_CONT_MinPriceMovePts_WDO` | `double` | `1.5` | Preservado; mínimo na mesma unidade de preço aplicado a progresso da onda, sem janela POC. |
| 48 | `Inp_Cont_RequireCandleDirection` | `bool` | `true` | Preservado, mesmo tipo/default. |
| 49 | `Inp_BandMultiplier_WIN` | `double` | `0.80` | Preservado, mesmo tipo/default. |
| 50 | `Inp_BandMultiplier_WDO` | `double` | `1.50` | Preservado, mesmo tipo/default. |
| 51 | `Inp_VWAP_Inner_Pct` | `double` | `0.60` | Preservado, mesmo tipo/default. |
| 52 | `Inp_VWAP_Outer_Pct` | `double` | `1.50` | Preservado, mesmo tipo/default. |
| 53 | `Inp_Rule_40_60` | `double` | `0.40` | Preservado, mesmo tipo/default. |
| 54 | `Inp_C2_WIN` | `double` | `700.0` | Preservado, mesmo tipo/default. |
| 55 | `Inp_C3_Min_WIN` | `double` | `125.0` | Preservado, mesmo tipo/default. |
| 56 | `Inp_C3_Max_WIN` | `double` | `400.0` | Preservado, mesmo tipo/default. |
| 57 | `Inp_C2_WDO` | `double` | `25.0` | Preservado, mesmo tipo/default. |
| 58 | `Inp_C3_Min_WDO` | `double` | `5.0` | Preservado, mesmo tipo/default. |
| 59 | `Inp_C3_Max_WDO` | `double` | `15.0` | Preservado, mesmo tipo/default. |
| 60 | `SigmaLookbackDays` | `int` | `5` | Preservado, mesmo tipo/default. |
| 61 | `Inp_SigmaFloor_WIN` | `double` | `200.0` | Preservado, mesmo tipo/default. |
| 62 | `Inp_SigmaFloor_WDO` | `double` | `7.0` | Preservado, mesmo tipo/default. |
| 63 | `Inp_MaxDeviationPts_WIN` | `int` | `100` | Preservado, mesmo tipo/default. |
| 64 | `Inp_MaxDeviationPts_WDO` | `int` | `2` | Preservado, mesmo tipo/default. |
| 65 | `Inp_EnableMacroDirectionGate` | `bool` | `true` | Preservado, mesmo tipo/default. |
| 66 | `Inp_EnableLateDirectionBlock` | `bool` | `true` | Preservado, mesmo tipo/default. |
| 67 | `Inp_EnableAbsorption` | `bool` | `true` | Preservado, mesmo tipo/default. |
| 68 | `Inp_EnableContinuation` | `bool` | `true` | Preservado, mesmo tipo/default. |
| 69 | `Inp_TurboLotsMultiplier` | `double` | `2.0` | Preservado, mesmo tipo/default. |
| 70 | `Inp_ExitMode` | `EXIT_MODE` | `PROGRESSIVE_NO_TP` | Preservado, mesmo tipo/default. |
| 71 | `Inp_MaxProtectedR` | `int` | `5` | Preservado, mesmo tipo/default. |
| 72 | `Inp_AggressionFilterMode` | `FAR_MODE` | `FAR_APLICAR` | Preservado, mesmo tipo/default. |
| 73 | `Inp_AggressionThresholdPct` | `double` | `60.0` | Preservado, mesmo tipo/default. |

## Inputs adicionados

| Input | Tipo | Default | Motivo e origem |
|---|---|---|---|
| `Inp_WaveBaselineMin` | `int` | `3` | Mínimo de ondas anteriores fechadas; máximo de dez no kernel. Default literal da referência verificada. |
| `Inp_WaveReversalPts_WIN` | `double` | `60.0` | Reconhecimento causal/reversão por preço WIN/IND. Default literal da referência verificada. |
| `Inp_WaveReversalPts_WDO` | `double` | `2.0` | Reconhecimento causal/reversão por preço WDO/DOL. Default literal da referência verificada. |
| `Inp_PathEventTicks` | `int` | `2` | Escala da amostragem por eventos de preço (ticks reais de negociação). Default literal da referência verificada. |
| `Inp_CONT_MinPathEfficiency` | `double` | `0.60` | Eficiência mínima por eventPath para CONT. Default literal da referência verificada. |
| `Inp_ABS_MaxPathEfficiency` | `double` | `0.30` | Eficiência máxima congelada no extremo para ABS. Default literal da referência verificada. |
| `Inp_ABS_MinRejectionFraction` | `double` | `0.35` | Rejeição posterior mínima proporcional ao progresso original. Default literal da referência verificada. |

## Limites e semântica

Os valores novos são hipóteses de engenharia da referência; não foram otimizados nem validados financeiramente. `Inp_ABS_MaxBodyPts_*` não foi transformado em AND geral de ABS, pois isso acrescentaria regra nova: seu único consumidor decisório original era `absStallStrict` dentro do contexto POC eliminado. Valores de POC não são reinterpretados como parâmetros Weis.

O default original de esforço ABS/CONT já é 1.50. Timeout permanece 300 s; margem WIN 175.0/WDO 3.5; late direction continua ligado. VWAP, sigma, M5/M1 e todos os defaults financeiros foram conservados. Fixtures completas do baseline: `tests/fixtures/inputs_original.json`.
