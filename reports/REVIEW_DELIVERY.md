# Revisão dirigida antes da homologação

Base da revisão: `85be544095be963c40707c8fd282722321d277a7`, branch `codex/reconstrucao-scalper-1995-weis`. Escopo limitado aos três pontos solicitados. O original `eu1995` e a especificação continuam intactos.

## 1. Presença, completude e integração dos includes

Os três arquivos estão versionados, completos e foram lidos integralmente. Os bytes permaneceram iguais à entrega-base. As declarações próprias de tipos, inputs, globais, APIs WW/LL, assinaturas e ordem dos includes são coerentes com o EA inspecionado. Não foi necessária correção de include.

`reports/REVIEW_INCLUDES.md` registra hashes e vínculos. Testes portáveis do kernel, engine e lifecycle foram repetidos com êxito. Isso não confirma compatibilidade nativa do EA completo com MetaEditor, seus overloads e bibliotecas padrão.

## 2. Epoch alterado: invalidação terminal da intenção

A inconsistência foi confirmada: `gWWEpoch` distingue revisões da prova analítica (reset/fault/revisão material de fronteira). Não há caminho para substituir o epoch congelado no ARMED, e os gates vivos recusam essa intenção permanentemente. Portanto, esperar até timeout depois de `THESIS_INVALIDATED` mantinha um estado sem possibilidade de revalidação.

A correção restrita introduz `EndRevisedWeisThesis()`:

1. Sem ARMED ativo ou com epoch igual, retorna sem efeito.
2. Com epoch distinto, preserva o ID e registra motivo exato `FROZEN_WEIS_EVIDENCE_REVISED` em `THESIS_INVALIDATED`.
3. Usa `ResetArmedSignal()` existente, que emite `SIGNAL_END`/`SIGNAL_ENDED` com o mesmo ID/motivo antes de limpar somente ARMED/FAR.
4. `ProcessArmedSignal()` retorna `APS_ENDED_FAIL_CLOSED`, antes de relógio/timeout, consulta de tick, FAR, confirmação e rompimento. Não retorna permissão de reavaliação.
5. `OnTick` verifica imediatamente depois de `WWService` e retorna antes de hard contradiction ou novo armamento. EOD, BE e reconciliação continuam antes da análise. Isso impede o caminho de hard-flip de rearmar na mesma chamada antes de a invalidação ser processada.
6. `OnTimer` verifica depois do serviço Weis e continua a drenagem/reconciliação já existente, permitindo encerrar mesmo sem outro tick.

O guard final de despacho continua recusando epoch distinto. Não recebe comandos de cancelar ordem, limpar pending, desbloquear journal ou liberar risco. As estruturas financeiras, pendências de entrada/saída, posições e correlações request/order/deal não são alteradas pelo helper. Se existe obrigação financeira, ela continua sob o protocolo original, mesmo que o ciclo analítico tenha terminado. Um fill atrasado permanece correlacionável pelo observador existente.

A indisponibilidade transitória com **mesmo epoch** continua em espera, com `THESIS_REVALIDATION`. Não foram introduzidos novos filtros de classificação, tempo, preço ou prioridade ABS/CONT. A correção muda somente o estado terminal quando a prova congelada já não pertence ao epoch atual. A precedência do motivo agora é a revisão da prova, mesmo quando a intenção também já expirou; ambos impedem envio.

## 3. MaxBody: perda funcional documentada, sem filtro novo

`Inp_ABS_MaxBodyPts_WIN/WDO` não altera mais elegibilidade de C1/entrada. No original seu efeito estratégico era exclusivamente `c1_body_ok` dentro de `absStallStrict`, ramo de POC sem deslocamento. Divergência e following-reaction não tinham esse AND universal.

A substituição autorizada de C1 eliminou esse ramo e o efeito estratégico do input. Nome, tipo, default e ordem foram preservados, mas isso não preserva a funcionalidade. Continua existindo um efeito de configuração: valor não positivo/não finito é recusado no init; o valor resolvido também aparece no snapshot/log. Não houve consumidor independente de POC que justificasse recolocá-lo numa regra da nova Weis.

`reports/REVIEW_MAX_BODY.md` compara o fato com as seções2–4 do comando mestre e demonstra a diferença. Não foi inventado um filtro de corpo universal nem alterado qualquer default. Caso a homologação futura exija preservar um controle de corpo fora do antigo stall POC, faltará uma regra explícita de como ele deve operar; esta entrega não presume equivalência.

## Resultado consolidado

`python3 tests/run_all.py` retornou0: **82 verificações aprovadas, zero falhas e zero skips** (25 kernel +23 ingestão +2 lifecycle +13 preservação +8 marcador +9 epoch +2 MaxBody). O log integral está em `reports/review_validation.log`. O controle negativo do epoch usa o corpo exato de ProcessArmedSignal da entrega-base e demonstra a falha terminal anterior; a correção passa o mesmo cenário.

## Diff, testes e limites

- `reports/SCALPER1995_REVIEW.diff`: diff completo de código contra85be544. Somente o helper de encerramento e as três integrações de epoch; includes e demais mecanismos não mudam.
- `reports/SCALPER1995_FULL.diff`: comparação cirúrgica atualizada contra o original preservado, mais os includes.
- `reports/SOURCE_MANIFEST.json`: hashes atuais da candidata e dos arquivos fundamentais.
- `reports/review_validation.log`: execução consolidada desta revisão; logs separados de includes/body e regressão anterior também preservados.
- `tests/test_review_epoch.py`: código real extraído com serviços simulados, eventos/IDs, terminalidade e proteção de estados; não é teste do broker ou recovery MT5 completo.
- `tests/test_review_max_body.py`: predicados reais extraídos, mostrando dependência antiga e ausência estratégica atual.

`COMPILACAO_NATIVA_NAO_VERIFICADA`

`REPLAY_NAO_VERIFICADO`

A consulta às ferramentas disponíveis continua sem MetaEditor, terminal MT5 ou Wine no PATH. Não há log nativo de compilação, erros/warnings nativos, sessão real de replay ou homologação. Os resultados locais não demonstram segurança operacional completa ou desempenho financeiro.
