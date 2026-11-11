# Revisão dos três includes da candidata 1.995

Escopo: confirmar presença, completude e contrato de integração de `Weis1996Kernel.mqh`, `Weis1996Engine.mqh` e `SignalLifecycle1995.mqh` com `RemoraScalper1995_Weis1996.mq5`. Esta revisão não altera os includes nem o EA.

## Integridade e presença versionada

`git ls-files` confirma os três includes e o `.mq5` no repositório. Os bytes dos três includes locais coincidem com `git show HEAD:<caminho>` na revisão-base `85be544` inspecionada. A leitura integral de cada include confirmou corpo, fechamento de funções e `#ifndef`/`#define`/`#endif`; não há include vazio, truncado ou substituído por stub.

| Caminho | Bytes | Linhas | SHA-256 |
|---|---:|---:|---|
| `include/Weis1996Kernel.mqh` | 6552 | 162 | `8aaef7aebe183a21537f64c2a4031ecaaaf88e5a2d79a075143f1d1a4337470e` |
| `include/Weis1996Engine.mqh` | 14704 | 323 | `357bfb526d023ec5c43b3358f416400099f183e34e8d584e59803f19986d3f3c` |
| `include/SignalLifecycle1995.mqh` | 10052 | 196 | `500338661e5f731dbecfd31ecc1194e0cdfd89105afcfd6ea12a318acd097504` |

`Weis1996Kernel.mqh` contém `OMBands` como payload estrutural inerte, `OMWave`, `OMWaveBook`, `OMConfig`, `OMDecision` e as funções numéricas completas `OMNumber`, `OMWaveReset`, `OMBaseline`, `OMStartWave`, `OMWavePush`, `OMAbsEvidence`, `OMClassify`. Não contém a política de bandas/localização da 1.996. A extração literal foi novamente conferida contra a referência vendorizada de blob Git `e0bacb9fa1e003ddb57c658c9cc8860e208cfbfc`.

## Ordem e vínculos com o EA

A ordem do `.mq5` é adequada ao contrato observado:

1. Bibliotecas padrão `Trade/Trade.mqh` e `Trade/PositionInfo.mqh`, depois kernel na linha 31 da revisão-base. `OMDecision` já existe antes dos campos de `MatrixSnapshot` e `ArmedSignal`.
2. Tipos do EA declarados antes da inclusão dos adaptadores: `MacroContext`, `MatrixSnapshot`, `ArmedSignal`.
3. Globais exigidos pelos adaptadores declarados antes dos includes: `gIsIndexFamily`, `gTickSize`, `gMagicCore`, `gBreakoutMargin`, `gABS_MinDisplPts`, `gCONT_MinDisplPts`, `gMacro` e `armed`.
4. Engine e lifecycle incluídos, respectivamente, nas linhas 956 e 957 da revisão-base. A inclusão repetida do kernel pelo engine é protegida pelo include guard.

O engine define integralmente os sete inputs Weis novos e todas as APIs consumidas no EA: `WWValidateInputs`, `WWInit`, `WWService`, `WWReady`, `WWLiveReady`, `WWGetClosed`, além dos tipos/globais numéricos usados na revalidação e nos diagnósticos. `WWGetClosed` recebe a abertura da última barra fechada (`iTime(...,1)`), de acordo com seu contrato. `WWInit` é chamado no init e no reset diário; a validação ocorre após resolver tick size, família e parâmetros originais. `WWService` continua após gestão financeira no tick/timer. `WWShutdown` não possui recursos próprios a liberar.

O lifecycle define `LLInit`, `LLRecord`, `LLFlush` e `LLClose` com as assinaturas utilizadas pelo EA. Os consumidores fornecem `ArmedSignal` e `OMDecision` compatíveis com os campos realmente lidos. O init abre o stream depois de identificar símbolo/Magic; o timer drena a fila; o deinit fecha o stream depois de registrar o encerramento do ARMED. `LLRecord` não escreve arquivo nem altera as estruturas de intenção recebidas por referência constante.

Não foi encontrado símbolo próprio consumido pelo EA e ausente dos três módulos, nem declaração conflitante de tipo/input entre eles. Não foi necessária correção de conteúdo ou caminho nos includes para o contrato inspecionado.

## Testes efetivamente repetidos nesta revisão

Log separado, preservando os resultados da entrega anterior: `reports/review_includes_validation.log`.

| Comando | Resultado |
|---|---|
| `python3 tests/run_weis_kernel_tests.py --reference references/ObjectiveMatrix.e0bacb9.mqh` | Identidade literal aprovada + 25 casos numéricos aprovados |
| `python3 tests/run_weis_adapter_tests.py` | 23 casos do corpo real do adaptador com serviços simulados aprovados |
| `python3 tests/test_lifecycle.py` | 2 métodos aprovados, incluindo execução do helper real com shim de serviços MQL |

As três chamadas retornaram exit status 0. São **50 verificações locais** nesta camada; nenhuma é operação financeira real. Não houve alteração dos arquivos de implementação dos includes.

## Limite da conclusão

A presença, integridade, contratos de símbolos e execução portátil dos módulos foram verificados. **Compatibilidade nativa do EA completo com o compilador/stdlib/build do MetaEditor permanece não verificada.** Os harnesses substituem sintaxe de arrays e serviços da plataforma; não verificam todos os tipos, overloads, encodings, preprocessor e APIs no compilador MQL5. As bibliotecas padrão `Trade/*.mqh` devem existir na instalação MT5 utilizada.

`COMPILACAO_NATIVA_NAO_VERIFICADA`

`REPLAY_NAO_VERIFICADO`

Nenhuma homologação é inferida desta revisão.
