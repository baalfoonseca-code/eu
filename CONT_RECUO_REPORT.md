# Correção cirúrgica — recuo CONT independente na Scalper 1.995

Base anterior: `e98b9bbb2e36f48d1d32ada196d5d3c96741357d`. Correção dos fontes: `0ecac27d81f8ebbf887d936305543af78122a019`. Os módulos alterados pertencem exclusivamente à reconstrução 1.995 neste projeto. A Scalper Bands 1.996 e a referência original não foram editadas.

Arquivo integral regenerado: `RemoraScalper1995_Weis1996_COMPLETA.mq5`, 9.525 linhas, 404.336 bytes.

SHA-256: `29802b83ed4952980910b39d546617cdb0da4c7adf1ef84bd670b98ca1be0e0a`.

## Mudança exata

O input existente continua com nome, tipo e default anteriores:

```mql5
input int Inp_PathEventTicks=2;
```

Dois inputs foram acrescentados depois dos sete inputs Weis existentes, preservando sua ordem relativa:

```mql5
input int Inp_CONT_MaxRecuoTicks_WIN=2;
input int Inp_CONT_MaxRecuoTicks_WDO=2;
```

Os 77 inputs anteriores não mudaram de default. O conjunto efetivo passa a **79** inputs. Os defaults de eficiência CONT 0.60, ABS 0.30, rejeição ABS 0.35 e baseline mínimo 3 continuam iguais, assim como os esforços e demais inputs originais.

`OMConfig` recebeu somente `double contMaxRecuo`. A configuração usa o tamanho real do tick resolvido por `OnInit` via `SYMBOL_TRADE_TICK_SIZE`:

```mql5
c.eventStep=Inp_PathEventTicks*gTickSize;
c.contMaxRecuo=(gIsIndexFamily?Inp_CONT_MaxRecuoTicks_WIN:Inp_CONT_MaxRecuoTicks_WDO)*gTickSize;
```

A única mudança numérica em `OMClassify` é:

```diff
- w.volume/w.baseline>=c.contEffort && drawdown<c.eventStep
+ w.volume/w.baseline>=c.contEffort && drawdown<c.contMaxRecuo
```

A comparação estrita foi mantida. O novo limite não é passado a `OMWavePush`, não é usado em `OMAbsEvidence` e não interfere em eventPrice/eventPath, baseline, esforço, pico, eficiência ou rejeição.

No EA modular houve somente atualização do comentário de C1, que antes descrevia `drawdown<eventStep`. Nenhuma expressão ou função operacional foi alterada no EA principal. `EndRevisedWeisThesis`, Stage 2 e os journals continuam como na revisão anterior.

## Defaults e fronteiras

Com todos os três inputs em 2, tanto o limite anterior quanto o novo são numericamente `2*gTickSize`. Portanto, o predicado e as decisões do núcleo são equivalentes à versão anterior sob os defaults, com os mesmos dados e demais parâmetros.

| Recuo observado | Limite2 ticks | Limite3 ticks |
|---|---|---|
| 0 tick | Aceito pelo predicado | Aceito pelo predicado |
| 1 tick | Aceito pelo predicado | Aceito pelo predicado |
| 2 ticks | Rejeitado | Aceito pelo predicado |
| 3 ticks | Rejeitado | Rejeitado |

“Aceito pelo predicado” pressupõe todos os demais critérios satisfeitos; não significa ordem enviada. Com tick 5 na família índice, dois ticks são 10 pontos; com tick 0.5 na família dólar, são 1 ponto. O código não fixa esses tamanhos: usa o valor real do símbolo.

Presets antigos com `Inp_PathEventTicks` diferente de 2 deixam de transportar seu limite de recuo implicitamente. Para reproduzir especificamente o limite antigo de um desses presets, o novo parâmetro da família precisa receber o antigo valor de PathEventTicks. Não houve migração ou alteração silenciosa de preset. Mudar a amostragem ainda pode mudar eficiência e classificação pelas medidas da trajetória, mas não modifica a tolerância numérica configurada.

## Validação sem teto estratégico

Ambos os novos inputs devem ser inteiros positivos. Zero ou negativo não define tolerância utilizável para o predicado estrito de um recuo não negativo; a configuração é recusada, sem clipping ou fallback. Os produtos pelo tick e o limite selecionado precisam ser finitos e representáveis.

Não há teto arbitrário, limitação pela reversão, igualdade com eventStep, ordenação entre os inputs ou dependência com PathEventTicks. O teste aceita `INT_MAX` nos novos inputs para ticks válidos. Permanecem as restrições **preexistentes** da amostragem (PathEventTicks positivo e reversão compatível com o passo); elas não foram transferidas ao recuo.

## Testes executados

Comando consolidado: `python3 tests/run_all.py`. Log integral: `reports/cont_recuo_validation.log`.

**101 verificações aprovadas, zero falhas e zero skips**: 25 kernel, 23 ingestão, 2 lifecycle, 13 preservação, 8 marcador econômico, 9 epoch, 2 MaxBody, 10 recuo independente e 9 consolidação. A conferência de proveniência verifica o blob original e permite exclusivamente o novo campo e a troca do predicado; não descreve o kernel adaptado como idêntico à 1.996.

O teste dedicado `tests/test_cont_recuo.py` compila em namespaces separados o kernel anterior exato e o atual, mais os corpos reais de `WWConfiguration` e `WWValidateInputs` com primitivas/inputs simulados. Não reimplementa o predicado testado.

| Exigência | Prova executada |
|---|---|
| Equivalência padrão | 140 comparações exatas de todos os campos OMDecision com o núcleo anterior, WIN/tick 5 e WDO/tick 0.5, compra/venda, recuos e condições de baseline/esforço/eficiência controlados |
| Fronteira estrita |0/1 tick aprovados e2/3 rejeitados em ambas as famílias e direções, mantendo os demais requisitos |
| Aumentar somente tolerância |2→3 admite recuo de 2; quando ambas as versões aprovam, as métricas de decisão são idênticas e o livro de ondas não muda |
| Independência de ABS |OMAbsEvidence ativa e anterior com resultados matematicamente exatos ao núcleo anterior; seus corpos e funções de ondas são literalmente preservados |
| Amostragem independente |Path 1/2/3 mantém contMaxRecuo; um feed irregular demonstra diferenças reais em eventPath e pathEfficiency sem mudar o limite de recuo |
| Famílias independentes |Alterar WIN ou WDO usa somente o input da família correspondente, com seus ticks distintos |
| Validação |Zero/negativo recusados em ambos; INT_MAX aceito; sem vínculo com Path ou reversão |
| Preservação |Todas as 315 funções do EA iguais após normalizar **somente** o comentário de C1 atualizado; referência 1.996, eu1995 e lifecycle byte a byte iguais |
| Monolítico |Build oficial --check e 9 testes de expansão;353 corpos de funções idênticos à versão modular atual,79 inputs e somente os dois includes oficiais |

Ao variar o recuo CONT, a evidência ABS continua idêntica, mas uma CONT recém-aprovada pode coexistir com ABS ativa/anterior e acionar o conflito já existente. Isso pode mudar classificação e sinais posteriores. Não é prometida igualdade das operações ABS do dia; não houve mudança da matemática ABS nem eliminação de conflitos.

A primeira execução de conservação apontou a atualização do comentário de C1; o teste foi ajustado para normalizar exatamente esse comentário e continuar recusando qualquer outra mudança nos corpos do EA. O build recusou os hashes antigos antes da atualização dos pins. Os pins finais correspondem aos fontes efetivamente versionados no commit 0ecac27; não houve edição manual do monolítico ou desativação da verificação.

## Build, diff e arquivos preservados

Regeneração utilizada:

```sh
python3 tools/consolidate_scalper1995.py --replace-generated 22708a7ae145037a31accde3b02279a4e123eb92eba4c6ccfb7a9b4e2074d6ef
python3 tools/consolidate_scalper1995.py --check
```

O novo argumento permite substituir um artefato gerado **somente quando seu hash atual coincide com o valor informado**; sem ele, o build conserva a proteção anterior contra sobrescrever conteúdo diferente. Os hashes dos fontes são conferidos independentemente antes da escrita. O modo --check continua sem escrever.

- `reports/CONT_RECUO_SOURCE.diff`: diff completo da correção de origem contra e98b9bb.
- `reports/CONT_RECUO_FULL.diff`: inclui a regeneração do monolítico e o ajuste do build.
- `reports/CONT_RECUO_AUDIT.md`: auditoria independente do escopo, isolamento e expansão.
- `reports/CONSOLIDATION_MANIFEST.json`: hashes atuais dos fontes e do arquivo integral.

C2–C5, VWAP/VWAP D‑1, H1/L1, sigma, macro M5, BASE/TURBO, Stage 2, triggers, timeout/overshoot, FAR, Magic, SL/TP, sizing, BE/progressão, stops, execução, persistência e recovery permanecem iguais. Não foi reintroduzida POC/Volume Profile.

A referência imutável `references/ObjectiveMatrix.e0bacb9.mqh` continua com a implementação 1.996 original, inclusive `drawdown<c.eventStep`; seu blob é `e0bacb9fa1e003ddb57c658c9cc8860e208cfbfc`. Não existe executável Scalper Bands 1.996 neste checkout e não foi editado outro repositório ou branch para afetá-lo. Os dois módulos alterados só são consumidos pelos artefatos 1.995 deste projeto.

## Limitações

**COMPILACAO_NATIVA_NAO_VERIFICADA**

MetaEditor, terminal MT5 e Wine não estão disponíveis no PATH da máquina inspecionada. Não há log nativo nem contagem de erros/warnings MetaEditor. Os testes usam C++ com serviços/primitivas simulados e pré-processamento para a consolidação; não são compilação MQL5.

**REPLAY_NAO_VERIFICADO** — não houve replay real ou execução em corretora, nem validação dinâmica de Stage 2, journals/recovery, latência e resultados financeiros. Preservação literal e testes determinísticos não homologam a estratégia. Não houve otimização de parâmetros ou alegação de rentabilidade.
