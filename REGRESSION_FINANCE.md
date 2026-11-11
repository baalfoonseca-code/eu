# Regressão financeira — reconstrução 1.995

## Escopo e estado

Auditoria estática integral das linhas 6001–9065 de `eu1995` e da especificação mestre. O código original não foi alterado. A suíte abaixo isola a função exata `PersistEconomicMarker` num harness C++ com mocks de I/O e arquivos reais temporários; não substitui o protocolo financeiro MQL5 nem comprova execução em corretora.

`COMPILACAO_NATIVA_NAO_VERIFICADA`

`REPLAY_NAO_VERIFICADO`

## Defeito preexistente: contagem do marcador

Em `eu1995:7198`, `PersistEconomicMarker` abre o marcador com `FILE_WRITE|FILE_TXT|FILE_ANSI`, escreve `S1995_ECONOMIC_OBLIGATION\r\n` e compara `written==25` (linha 7208). O conteúdo possui 25 caracteres antes do CRLF e 27 caracteres/bytes ASCII com CRLF. Sob o contrato de retorno em bytes escritos de `FileWriteString`, uma gravação integral retorna 27 e a comparação a classifica incorretamente como falha.

A consulta à referência oficial <https://www.mql5.com/en/docs/files/filewritestring> foi tentada, mas o proxy respondeu `CONNECT 403 Forbidden` nesta sessão. O contrato acima não foi revalidado por consulta online nem por execução nativa; a prova executada usa explicitamente esse contrato como premissa. O conteúdo ASCII e o erro aritmético são verificáveis localmente.

Impacto demonstrável estaticamente:

- Na primeira criação do sentinela PID0, `RestoreUnresolvedEconomicMarkers` (7215–7221) interpreta o falso retorno como falha de varredura, marca `gEconomicMarkerScanUnresolved` e retorna antes de enumerar os marcadores.
- Em criação de PID, `SyncEconomicMarker` (7270–7285) pode marcar `economicMarkerPending` apesar de o arquivo ter sido gravado integralmente. `RecomputeAccountingBlock` (6901–6938) inclui esses estados e bloqueia novas entradas.
- O comportamento é conservador: não há prova aqui de ordem duplicada ou liberação indevida. Como a presença do arquivo já retorna `true` antes de escrever, uma tentativa posterior pode superar o falso erro. Não afirmar bloqueio permanente.
- Arquivo parcial existente continua representando obrigação não resolvida. Retorno `true` por presença não é confirmação de resultado econômico; a correção não muda essa regra.

Correção mínima aplicada na candidata; o patch de reprodução está em `patches/economic-marker-length.patch`: somente `written==25` → `written==27` na candidata nova. Nenhuma alteração de risco, despacho, journaling ou limpeza. Versionada em commit separado do diff estratégico. O patch mantém o literal, flags, `ResetLastError`, `FileFlush` e a precedência da obrigação existente.

## Testes executados

Comando: `python3 tests/finance/test_economic_marker.py` no repositório.

O runner extrai o texto exato de `PersistEconomicMarker` do original, compila a função em C++ (`g++ -std=c++17 -Wall -Wextra -Werror`) e compara com a mesma função contendo exclusivamente a correção de comprimento. A escrita e o flush utilizam `fwrite`, `fflush` e `fsync` sobre arquivos temporários. Um segundo processo reproduz a perda de estado RAM da função após reinício. Falhas de abertura, escrita curta e flush são injetadas. Isto testa a decisão isolada, não as implementações MetaTrader dessas APIs.

| Caso | Resultado observado no harness |
| --- | --- |
| Comprimento literal | 27 bytes ASCII; 25 sem CRLF |
| Primeira escrita integral original | Retorna falso apesar de bytes exatos e flush |
| Primeira escrita integral corrigida | Retorna verdadeiro com bytes exatos e flush |
| Reinício em novo processo | Ambas reconhecem presença sem sobrescrever nem apagar |
| Sentinela PID0, criação e retry | Original falha na criação e passa no retry; corrigida passa em ambos |
| Falha de abertura | Ambas retornam falso, arquivo ausente |
| Escrita curta | Ambas retornam falso e preservam evidência parcial |
| Falha de flush | Ambas retornam falso e preservam evidência |
| Função da candidata | Verificada pelo runner quando o arquivo existir e contiver a correção isolada |

Execução inicial: 7 aprovados e 1 ignorado porque a candidata ainda não existia. Antes de aplicar a correção, a verificação da candidata refutou `written==25`. Execução final após aplicação: **8 métodos aprovados, zero falhas e zero ignorados**, incluindo a função corrigida exata da candidata. O protocolo completo MT5 permanece pendente.

## Mapa protegido lido

| Área | Referências do original | Invariante a conferir no diff final |
| --- | --- | --- |
| Ordens irresolvidas | 6007–6440; `RememberUnresolvedOrder`, `PendingOrderFillEvidence`, `ProvenOrderFillComplete`, `ReconcileUnresolvedOrders` | Identidade exata, volume completo, classificação e persistência antes de liberação |
| Recuperação da posição | 6489–6558; `ReconstructOpenPosition` | Ownership, netting/hedging e histórico indisponível mantêm bloqueio |
| Resultado diário | 6560–6765; `RestoreDailyEconomicsFromHistory`, `RestoreDailyPersistence` | Soma por ciclo, custo/R, stop latched, fallback persistido não certifica histórico |
| Reconciliação | 6860–7042; `SyncAccountingState`, `RecoverAccountingInfrastructure` | Tick barato; histórico no timer/transação; obrigações não liberadas por ausência |
| CSV financeiro | 7044–7077 | Reabertura sem truncar, schema/tail impedem append inválido |
| Eventos financeiros | 7081–7159; `ProcessAccountingDeal`, filas diferidas | DEAL_ADD próprio preservado mesmo quando histórico temporariamente indisponível |
| Marcadores econômicos | 7161–7346 e 7348–8190 | Presença é obrigação; recibo exige prova fresca de histórico, posição, ordens e BE |
| Requests persistentes | 8192–8678 | PREPARED separado de MAY_HAVE_DISPATCHED; tail rasgado não vira prova de não envio |
| Obrigações exatas | 8681–8948 | Snapshot não é prova terminal; identidade sobrevive indisponibilidade |
| Inicialização/meia-noite | 8950–9012 | Estado aberto, intent de saída e request pendente sobrevivem |
| Transações | 9014–9057 | Handlers EMR e BE, contabilidade e reconciliação antes dos observadores analíticos |

## Testes financeiros ainda não executados

Nenhum teste real de ordem aceita/fill, rejeição, resultado incerto, parcial, reinício após envio, BE pendente, posição estrangeira, falha de journal, EOD, indisponibilidade de histórico ou ausência de duplicação foi executado no MT5 nesta sessão. Essas exigências da seção 17.G permanecem pendentes, mesmo que funções sejam preservadas literalmente.

A equivalência estática do protocolo completo deve ser verificada contra a candidata após o diff estratégico. O harness de marcador não é prova dessa equivalência nem homologação financeira.
