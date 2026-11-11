# Revisão do epoch da tese Weis

Referência anterior: commit `85be544095be963c40707c8fd282722321d277a7`.

## Defeito demonstrado

O motor incrementa `gWWEpoch` quando reinicia sua análise diária/por símbolo, encontra falha permanente ou descobre negócios adicionais que invalidam um fechamento já congelado. A intenção guarda a geração de sua evidência em `armed.weisEpoch`. Uma diferença entre essas gerações não é indisponibilidade transitória: a intenção antiga não pode recuperar a mesma geração sem reconstruir sua origem, comportamento proibido pela especificação.

A entrega anterior registrava `THESIS_INVALIDATED` somente depois de obter tick, confirmar trigger e passar pelos guards iniciais; depois retornava `APS_STILL_ARMED`. Sem novo negócio/rompimento, nem o evento era observado. Quando observado, o ARMED permanecia ativo, embora `LiveWeisForArmed` nunca voltasse a aceitar a prova antiga.

O caller também avaliava hard contradiction antes de chamar `ProcessArmedSignal`, podendo seguir a política de reset/rearm sem reconhecer primeiro a revisão da evidência. O teste da correção, portanto, precisa cobrir os callbacks além do retorno da função.

## Correção limitada

`EndRevisedWeisThesis()` encerra somente a intenção analítica ativa quando os epochs diferem. Antes da limpeza, fixa os motivos `entryReason` e `lifecycleReason` em `FROZEN_WEIS_EVIDENCE_REVISED` e emite `THESIS_INVALIDATED` pelo diagnóstico existente. `ResetArmedSignal` emite `SIGNAL_END`, mapeado pelo helper de telemetria para `SIGNAL_ENDED`, com o mesmo ID e motivo; só então limpa o ARMED e sua evidência FAR.

Chamadas:

- Início de `ProcessArmedSignal`: retorna `APS_ENDED_FAIL_CLOSED`, antes de tick, FAR, timeout ou rompimento.
- `OnTick`, depois de `SyncAccountingState`, EOD, BE e `WWService`: termina o callback de entrada antes de hard contradiction/rearm.
- `OnTimer`, depois da reconciliação/EOD e `WWService`: encerra a intenção sem aguardar novo tick; o restante do timer e o flush continuam.

Não se retorna `APS_ENDED_REEVAL_ALLOWED` para esse caso: esse estado autoriza o caller a reavaliar uma nova intenção no mesmo callback quando há M1 novo. A política original de timeout continua usando esse estado quando o epoch é o mesmo. Indisponibilidade transitória, sem mudança de geração, continua aguardando.

Nenhuma chamada nova limpa `gPendingExec`, `gPendingExit`, posição ou journal. Encerrar o ciclo analítico não significa que um request financeiro anterior foi resolvido, que não houve fill ou que uma obrigação pode ser liberada. Os snapshots de correlação de dispatch existentes continuam intactos.

## Testes executados

Comando: `python3 tests/test_review_epoch.py`.

**9 métodos aprovados**, sem falhas ou skips:

1. ABS/CONT e BUY/SELL com epoch diferente encerram imediatamente mesmo sem tick ou trigger.
2. Epoch revisado prevalece sobre timeout expirado e não permite reavaliação imediata.
3. Epoch igual sem tick preserva ARMED/idade.
4. Epoch igual com onda temporariamente indisponível continua em `APS_STILL_ARMED` e registra revalidação, sem invalidação.
5. Timeout com epoch igual mantém o retorno original `APS_ENDED_REEVAL_ALLOWED`.
6. Helper com intenção inativa não altera estado nem emite eventos.
7. Ordem dos callbacks garante finanças antes da análise e término antes do novo armamento.
8. Controle negativo: o corpo exato anterior de `ProcessArmedSignal` falha na mesma asserção terminal; a versão corrigida passa.
9. Comparação com a fotografia anterior prova alteração literal apenas em `ProcessArmedSignal`, `OnTick` e `OnTimer`, além do helper novo; os três includes mantêm seus hashes.

O harness compila os corpos reais de `ResetArmedSignal`, `EndRevisedWeisThesis` e `ProcessArmedSignal` em C++17 com mocks explícitos de APIs. A única adaptação sintática no processo é `(string)waveDir` para conversão inteira C++. O teste verifica sequência e identidade dos eventos antes da limpeza e ausência de chamadas a mutadores financeiros/sends, mantendo sentinelas de pendências, posição e accounting. Os serviços financeiros são mocks: isso **não** é teste do protocolo financeiro completo, de uma corretora ou das APIs nativas do MT5.

`COMPILACAO_NATIVA_NAO_VERIFICADA`

`REPLAY_NAO_VERIFICADO`
