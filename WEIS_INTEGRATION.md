# Integração Weis — candidata experimental 1.995

## Identidade e fronteira

O fonte original é `eu1995`, Git blob `a764baec7f716ad893ee82ae807d91e2c45f3986`, SHA-256 `2479ed8e5c9189438d787be1e804abbd95f9e1c06e01042e560251e64ef67fc5`. O original permanece preservado.

A referência efetivamente consultada é `baalfoonseca-code/Bf`, branch `codex/remora-matriz-objetiva`, `include/ObjectiveMatrix.mqh`, blob Git **`e0bacb9fa1e003ddb57c658c9cc8860e208cfbfc`**. A cópia auditável está em `references/ObjectiveMatrix.e0bacb9.mqh`; o blob Git identifica os bytes, não se confunde com SHA-256.

`include/Weis1996Kernel.mqh` extrai literalmente `OMBands` (somente payload estrutural), `OMNumber`, `OMWave`, `OMWaveBook`, `OMWaveReset`, `OMBaseline`, `OMStartWave`, `OMWavePush`, `OMConfig`, `OMDecision`, `OMAbsEvidence` e `OMClassify`. O harness confere os trechos contra a referência. `OMBands` fica zerada no adaptador; não há uso decisório de `attemptBands`. Não foram importados `OMWeighted`, `OMBuildBands`, `OMLocationEligible`, `OMInsideB3`, a política completa de `OMRevalidate`, gates de sigma, warmup de bandas, gap de 30 segundos ou seleção de sessão broker da 1.996.

## Comparação com a Weis original

A 1.995 original reconstrói até 150 candles do timeframe de sinal em `RebuildWeisCache`. A direção segue diferenças entre fechamentos, com carregamento da direção anterior nos empates. O volume vem de `CopyRealVolume` quando a consulta retorna todas as barras, ou de tick volume. A média usa até dez ondas fechadas. `ComputeLiveWaveO1` acrescenta volume e fechamento do candle vivo à onda anterior ou inicia uma onda viva oposta. Não mede percurso por eventos nem rejeição congelada no extremo.

A candidata substitui esse mecanismo por negócios executados de `COPY_TICKS_TRADE`, processados cronologicamente. Mantém a matriz e a criação de intenções no fechamento do timeframe de sinal, cujo default original continua M1. Contexto M5, VWAP vigente/D-1, sigma histórico, bandas e confluências restantes continuam na engenharia 1.995. Não se adotou a matriz nem a localização da 1.996.

## Formação causal e baseline

A primeira onda começa com direção desconhecida. A direção só é reconhecida quando `abs(price-start) >= reversal`, no timestamp observado (`recognitionMsc`); nenhum pivô autoriza entrada retroativa.

Uma onda direcional reverte quando `high-price >= reversal` na alta, ou `price-low >= reversal` na baixa. A onda anterior é fechada e seu volume entra no ring de até dez ondas. O negócio que reconhece a reversão pertence **uma única vez à onda nova**, no preço observado, conforme o kernel exato. Não se reposiciona o início da onda nova no extremo antigo.

`baseline = sum(closedVolume[0..count-1])/count`. O valor e `baselineCount` são congelados ao iniciar a onda; o volume da onda ativa não contamina sua própria referência. O default mínimo é três ondas anteriores fechadas. Baseline ausente produz indisponibilidade de evidência, sem esforço fabricado.

## Percurso e esforço

- `grossPath += abs(price-last)` a cada negócio da mesma onda.
- Quando `abs(price-eventPrice) >= eventStep`, `eventPath += abs(price-eventPrice)` e `eventPrice=price`.
- `eventStep = Inp_PathEventTicks * tickSize`, default dois ticks reais.
- Progresso atual: `net = dir*(close-start)`.
- Progresso amostrado: `eventNet = dir*(eventPrice-start)`.
- Eficiência atual: `eventNet/eventPath`, somente quando o denominador é positivo.
- Esforço atual: `volume/baseline`.

Num novo extremo de progresso, o kernel congela `peakNet`, `peakVolume`, `peakRaw`, `peakEvent`, `peakEventNet` e `peakMsc`. A rejeição posterior não pode reduzir artificialmente a eficiência da tentativa já congelada. `grossPath` permanece diagnóstico; não substitui `eventPath` no predicado de eficiência.

## C1 ABS

A tentativa deve ter direção reconhecida, baseline suficiente, `peakNet >= minAbs`, `peakEvent > 0`, `peakEventNet > 0`, volume no extremo positivo e timestamp de avaliação estritamente posterior a `peakMsc`.

A rejeição é `high-close` na tentativa de alta e `close-low` na tentativa de baixa. Exige simultaneamente:

- `rejection >= tickSize`;
- `rejection >= minRejection * peakNet`;
- `peakVolume/baseline >= absEffort`;
- `peakEventNet/peakEvent <= absEfficiency`.

Defaults da referência: esforço 1.50, eficiência máxima 0.30 e fração mínima de rejeição 0.35. A direção ABS é oposta à tentativa. Alto esforço ou preço parado sem rejeição não bastam.

O kernel examina tentativa ativa e a tentativa anterior fechada, conservando seus extremos/esforço originais. A matriz 1.995 continua exigindo localização/confluências próprias. O limite mínimo de deslocamento vem dos inputs originais ABS (WIN 60.0, WDO 2.0), agora aplicado à extensão da onda, e não à diferença de últimos preços de duas janelas POC.

## C1 CONT e conflito

CONT exige direção reconhecida e baseline suficiente, `eventPath > 0`, `net >= minCont`, `eventNet > 0`, `eventNet/eventPath >= contEfficiency`, `volume/baseline >= contEffort` e **`drawdown < eventStep`**. O drawdown é `high-close` na alta e `close-low` na baixa; igualdade bloqueia. Essa condição está presente no blob consultado e não foi omitida.

Defaults: esforço 1.50 e eficiência mínima 0.60. Os deslocamentos originais CONT continuam WIN 50.0/WDO 1.5, com a nova semântica de progresso de onda. A direção da candidata deve concordar com a onda. O requisito original configurável de direção do candle CONT continua na matriz 1.995.

Se mais de uma evidência real for aprovada entre CONT, ABS ativa e ABS anterior, `OMClassify` retorna NEUTRO com `reasonCode=4`. Não há preferência arbitrária, inclusive para evidências do mesmo lado. Isso é distinto do `ROUTE_CONFLICT_BLOCK` da matriz. Falta de baseline (`reasonCode=1`), trajetória inválida (`2`) e ausência de tese confirmada (`3`) permanecem causas distintas.

## Stage 2

O motor antigo de candles e seu cache deixam de validar o disparo. `LiveWeisForArmed` usa a onda ativa causal e exige direção reconhecida, baseline suficiente e esforço atual no limiar `armed.breakoutEffortMin` já existente. Para ABS, a tentativa rejeitada de Stage 1 e a reação de Stage 2 são evidências diferentes: não se exige que a reação tenha baixa eficiência.

O gate de Stage 2 continua sendo direção/esforço; não foi acrescentada uma segunda classificação C1 com novos filtros de eficiência/rejeição. Timeout, preço de referência/trigger congelado, margem, overshoot, spread, direção tardia, VWAP/glass, FAR e barreiras financeiras conservam seus papéis. O epoch identifica revisão material da evidência; dados revistos não substituem silenciosamente um snapshot congelado.

## Adaptador de negócios e disponibilidade

`include/Weis1996Engine.mqh` usa `CopyTicksRange` com intervalos inclusivos convertidos de `[cursor,endExclusive)`. Cada lote termina antes ou no fechamento da barra; o snapshot é classificado **antes** de consumir qualquer negócio da barra seguinte.

A validação exige preço positivo/finito/na grade real, timestamp em milissegundos coerente com os segundos, volume positivo/finito e flags de negócio. Atualização exclusiva de Bid/Ask não cria um negócio. A primeira fonte válida fixa o volume na sessão: `volume_real` positivo ou `volume` inteiro. Mistura de fontes bloqueia a evidência e não produz média sintética.

Os negócios do último milissegundo são guardados com multiplicidade e ordem. A releitura compara o prefixo inteiro; negócios adicionais são aplicados uma vez. Dois negócios distintos ou idênticos no mesmo milissegundo não são reduzidos a um. Remoção/reordenação/revisão de prefixo torna a evidência indisponível. Append tardio que afete um snapshot fechado invalida esse snapshot, sem recalcular sinais passados.

A reconstrução começa à meia-noite do dia do broker e avança até o timestamp observado, sem usar horários D1 como gate de entrada. O reset segue o mesmo calendário de `DailyReset` da 1.995. Reinício, reconexão, dia novo ou troca de símbolo não reaproveitam evidência de outra origem. Durante catchup, fechamentos são warmup; somente fechamentos posteriores a attach e após prontidão anterior podem formar novo snapshot. O motor não chama o armamento.

A prontidão viva exige cursor posterior ao timestamp da cotação atual e identidade do último negócio quando a atualização contém flags de negócio. Cotação exclusiva de Bid/Ask pode carregar Last retido e não é usada para fabricar nova evidência de negociação. Não se importou limite arbitrário de silêncio do feed: consultas bem-sucedidas não demonstram completude de toda a bolsa, e ausência de negócios não vira confirmação.

O adaptador deve ser chamado depois das rotinas financeiras de proteção/reconciliação. Falha analítica pode impedir nova evidência de entrada; não impede BE, EOD ou recuperação de uma posição existente.

## Custos e limites

Limites de trabalho: quatro intervalos por serviço, até 10.000 ms por intervalo, cap aplicado de 50.000 registros e orçamento suave de 10.000 µs após uma chamada. Intervalo acima do cap é reduzido progressivamente até um milissegundo; excesso mesmo nesse mínimo permanece indisponível. Não são parâmetros de vantagem estatística.

`CopyTicksRange` não aceita limite de contagem: o broker pode alocar mais registros internamente antes de retornar e o cap ser verificado. O orçamento suave tampouco interrompe uma consulta bloqueante. Não se declara garantia preemptiva de CPU/memória/latência.

Custos de serviço/histórico, lag e ring de 128 amostras são expostos para telemetria. Medições host com mocks não substituem p95/p99 reais em MT5; não foram medidos custos reais de feed nesta máquina.

## Limitação semântica confirmada da referência

O kernel só atualiza `peakVolume` quando `progress > peakNet`. Negócios adicionais no mesmo preço extremo aumentam `volume`, mas não atualizam `peakVolume`. Logo, fragmentação de volume em múltiplos negócios no mesmo preço preserva volume total/eventPath e pode preservar CONT, porém **pode alterar esforço congelado de ABS**. O teste determinístico demonstra essa propriedade. Ela foi preservada por fidelidade ao módulo obrigatório e não foi silenciosamente corrigida. A métrica por eventos reduz uma classe de dependência da fragmentação; não prova invariância total da classificação.

## Defeito refutado e corrigido durante auditoria

A primeira versão do adaptador reutilizava 09:00–18:25/18:30 das constantes de cálculo D1 como limites do replay Weis. A auditoria identificou que esses limites não são horários de entrada: os inputs originais permitem horários diferentes. Isso teria introduzido veto indevido antes de 09:00 ou após o término D1. A correção removeu esse gate, iniciou o replay à meia-noite do dia broker e passou a avançar até `latest.time_msc+1`. Os horários de entrada originais não foram alterados. Os testes do adaptador incluem execução analítica antes de 09:00 e após 18:25 para impedir regressão.

## Provas e status

O harness `tests/weis_kernel_test.cpp`, executado por `tests/run_weis_kernel_tests.py`, inclui o kernel real com shim C++, verifica seus segmentos literais contra a referência e cobre reconhecimento causal, baseline fechado, ring, reversões, mesmo milissegundo, ABS/CONT, retração estrita e conflito. As provas do coletor têm harness separado; consulte `TEST_RESULTS.md` para a execução final e suas limitações.

`COMPILACAO_NATIVA_NAO_VERIFICADA` — C++ host não é compilação MQL5.

`REPLAY_NAO_VERIFICADO` — nenhum resultado financeiro, acurácia ou vantagem estatística foi demonstrado. A candidata permanece experimental e não homologada.
