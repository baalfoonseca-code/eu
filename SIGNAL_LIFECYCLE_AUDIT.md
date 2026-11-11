# Auditoria do ciclo de sinal

## Instrumentação entregue

`include/SignalLifecycle1995.mqh` cria o arquivo analítico separado
`Scalper1995_WeisLifecycle_v1_<instância>.csv`. Não consulta ou altera o journal
financeiro, ordens, posições, risco, gatilhos ou o estado do ARMED. `LLRecord`
apenas captura os valores disponíveis e enfileira uma linha em memória;
`LLFlush` persiste lotes no timer e `LLClose` tenta drenar o restante no deinit.
O schema financeiro histórico não recebe novas colunas.

O ID fornecido pelo chamador é preservado. Um candidato que se torna ARMED deve
reutilizar o mesmo ID. O helper não cria IDs e não correlaciona sinais usando
preço semelhante, horário, Magic ou direção. A correlação financeira continua
sendo feita pelos vínculos exatos de request/order/deal existentes no fonte.

A decisão `OMDecision` inclui ID da onda, classificação, reason code, instante
da evidência, esforço, eficiência por eventos, progresso, percurso bruto,
percurso por eventos, rejeição e volume. O timestamp de observação é o do tick
conhecido; na ausência dele usa o relógio do servidor com precisão de segundos.
`WEIS_DIRECTION` é a direção da evidência, não uma alegação sobre o corpo do
candle. As colunas macro `*_OBSERVED` são a fotografia no enfileiramento;
não são falsamente descritas como o contexto congelado de um fill atrasado.
A idade macro é calculada desde a abertura da barra de referência indicada.

Gatilho, sizing, preços de request e dados de fill são vazios quando ainda
indisponíveis. Em particular, lote zero no Stage 1 não vira "sizing falhou".
`FILL_*` somente é preenchido com deal, timestamp, preço e volume positivos.
Request/order/deal/retcode só são preenchidos quando fornecidos pelo caminho
que efetivamente conhece esses identificadores.

## Eventos e significado

| Evento registrado | Evidência/limite |
|---|---|
| SIGNAL_CANDIDATE / SIGNAL_REJECTED / SIGNAL_DETECTED | Snapshot fechado e caminho da matriz instrumentados pelo chamador; nenhuma ordem é presumida |
| ARMED | Intenção ativa, ainda sem sizing final ou envio presumido |
| THESIS_REVALIDATION / THESIS_INVALIDATED | Resultado da revalidação causal; não renova relógio ou trigger |
| ROUTE_CONFLICT_BLOCK / MACRO_DIRECTION_BLOCK / FAR_CANCEL | Motivo observado de bloqueio, sem preferência nova de rota |
| TIMEOUT_ARMED | Expiração do relógio original |
| TRIGGER_CONFIRMED | Mapeia o evento original REAL_TRADE_CONFIRMED; confirmação do gatilho, não fill |
| SEND_ATTEMPT | Apenas quando o chamador alcança a chamada efetiva de envio |
| REQUEST_ACCEPTED / REQUEST_REJECTED / ORDER_FAILED | Aceitação, rejeição final ou falha/incerteza devem continuar distintas pelo resultado real |
| REQUEST_IDENTITY_BOUND | Mapeia DISPATCH_RESULT_BOUND; vínculo de IDs não comprova aceitação nem execução |
| DEAL_CONFIRMED | Mapeia FILL_CONFIRMED, já vinculado a deal real pelo observador original |
| DEAL_CONFIRMED_INOUT_UNEXPECTED | Preserva anomalia INOUT; não a reclassifica como entrada normal |
| SIGNAL_ENDED | Mapeia SIGNAL_END; encerra o ciclo analítico do ARMED, não quita obrigação financeira |

`ORIGINAL_EVENT` preserva o nome recebido. Eventos desconhecidos não são
convertidos por heurística em aceitação/rejeição/fill. Um fill atrasado pode
aparecer depois de SIGNAL_ENDED, com o mesmo ID preservado pelo vínculo exato.
`SIGNAL_ENDED` depois de SEND_ATTEMPT com resultado incerto não significa
"sem operação"; o desfecho financeiro permanece pendente até a prova real.

## Limites e perdas explícitas

A fila comporta 512 eventos. O timer drena no máximo 128 por chamada;
`LLClose` drena até 512. Quando a fila está cheia, eventos adicionais são
contados em `DROPPED_TOTAL`; `TELEMETRY_DROPPED` documenta a perda sem inventar
intenção, IDs ou resultado. Esse registro de metadados não possui sequência de
observação. A sequência de eventos também permite detectar lacunas.
Revalidações consecutivas com a mesma identidade/classificação/motivo no mesmo
segundo são agregadas e contadas em `COALESCED_TOTAL`; não se agregam fills,
requests ou transições terminais. Campos textuais acima de 2048 caracteres
recebem `[FIELD_TRUNCATED]`.

Falha de abertura/escrita da telemetria não bloqueia BE, EOD, recovery ou envio.
Uma escrita parcial torna a persistência analítica não confirmada e desliga o
stream, evitando repetição de linha parcialmente persistida. Eventos em fila
podem ser perdidos em crash, encerramento abrupto ou disco indisponível. Isso
é uma limitação explícita; o helper não afirma desfecho observado nesses casos.
O journal financeiro existente continua sendo a autoridade para recuperação.
O stream antigo de diagnóstico e seus custos preexistentes são independentes.

## Verificações executadas

`python3 tests/test_lifecycle.py` executou dois testes:

1. Contrato de 49 colunas e ausência de I/O ou chamadas financeiras em
   `LLRecord`.
2. Compilação C++17 do helper real com serviços MQL simulados e uma adaptação
   mecânica da declaração do array dinâmico de bytes. Verificou enfileiramento
   sem escrita/flush; escaping CSV; ausência de gatilho fictício no candidato;
   513 eventos resultando em 512 retidos e um descartado; drenagem limitada;
   registro explícito de perda; preservação de multiplicidade e IDs de fills;
   falha de escrita analítica sem modificar intenção ou dispatch.

Resultado: **2 testes aprovados**. Não são compilação MetaEditor, teste do
protocolo financeiro real, replay MT5 ou prova de latência em carga de mercado.
Não houve amostra operacional real nesta validação; não são apresentados
exemplos fictícios de logs como se fossem sinais/fills observados.

A integração efetiva dos pontos de chamada no EA deve ser conferida no diff
final e nos demais relatórios. A presença do helper sozinha não comprova
cobertura completa de todos os motivos terminais.

## Revisão dirigida posterior à entrega-base85be544

`EndRevisedWeisThesis` distingue prova definitivamente revisada de indisponibilidade transitória. Com epoch distinto, registra `THESIS_INVALIDATED` e depois `SIGNAL_ENDED` pelo caminho existente de ResetArmedSignal, preservando o mesmo ID e motivo `FROZEN_WEIS_EVIDENCE_REVISED` antes de limpar a intenção. O encerramento não altera pendências, journals, posições ou a correlação armazenada de requests/fills. OnTick retorna antes de hard-flip ou novo armamento nessa chamada; o timer pode encerrar sem novo tick. Com epoch igual e dados vivos temporariamente ausentes, o comportamento continua de espera e o evento é `THESIS_REVALIDATION`. Filas/falhas de disco mantêm as limitações já descritas.
