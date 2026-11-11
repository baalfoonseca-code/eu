# Consolidação integral da Rêmora Scalper 1.995

Arquivo final: **`RemoraScalper1995_Weis1996_COMPLETA.mq5`**,9515 linhas e 403752 bytes. Foi gerado integralmente, sem cortes ou pseudocódigo, a partir da revisão corrigida mais recente da branch `codex/reconstrucao-scalper-1995-weis`, commit **`ac0540261d6f0e578e79bddd46ff26ff65f317e8`**. O HEAD remoto dessa branch foi consultado antes da geração e coincidiu com essa revisão local.

SHA-256 do arquivo completo:

```text
22708a7ae145037a31accde3b02279a4e123eb92eba4c6ccfb7a9b4e2074d6ef
```

## Incorporação e ordem

Os corpos funcionais completos de `Weis1996Kernel.mqh`, `Weis1996Engine.mqh` e `SignalLifecycle1995.mqh` foram incorporados nos pontos originais de inclusão. O kernel continua antes dos tipos do EA que utilizam `OMDecision`; engine e lifecycle continuam depois dos tipos/inputs/globais exigidos. Guards e macros funcionais foram preservados.

O engine também incluía o kernel. Essa segunda diretiva é substituída por comentário que indica a incorporação anterior; nenhuma segunda definição é emitida. Isso reproduz o efeito do include guard original, sem duplicar estruturas ou funções. As demais linhas dos módulos permanecem presentes; os marcadores BEGIN/END permitem localizar os corpos incorporados. Não há módulo apenas referido por comentário sem sua implementação no arquivo.

Apenas estas dependências externas permanecem:

```cpp
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
```

Ambas pertencem à biblioteca padrão oficial do MT5. Não resta `#include` de arquivo personalizado.

## Resultado da auditoria de equivalência

| Exigência | Evidência obtida |
|---|---|
| Três módulos integralmente incorporados | Comparação independente do corpo de cada módulo, descontando só a diretiva local expandida; cada guard funcional aparece uma vez |
| Sem include personalizado pendente | Busca de diretivas confirma somente os dois includes oficiais |
| Sem declarações duplicadas | Inventários sem duplicação de 353 funções, 33 tipos, 294 variáveis globais (incluindo inputs) e 77 inputs |
| Referências internas | 38 nomes de funções OM/WW/LL consumidos têm definição; tipos/globais e todos os tokens de referência são os mesmos da unidade modular expandida. Não foi introduzida referência própria nova ou ausente |
| Inputs | 77 nomes, tipos, ordem efetiva e valores padrão idênticos |
| Condições decisórias | 78031 tokens ativos iguais pela expansão independente; outro teste compara o texto efetivo produzido pelo pré-processador C, sem diferenças |
| Financeiro |Todas as 353 funções têm corpos literalmente iguais, inclusive SendOrder, sizing, OnTradeTransaction, marcador econômico, BE, EOD, journals e reconciliação |
| Última revisão |EndRevisedWeisThesis e suas chamadas em ProcessArmedSignal/OnTick/OnTimer preservadas literalmente; marcador mantém written==27 |
| Arquivos protegidos |EA modular, três módulos e eu1995 permanecem byte a byte iguais à base ac05402. Nenhum mecanismo ou input foi editado |

Não houve reordenação de código funcional, mudança de C1–C5, ondas, ABS/CONT, VWAP/sigma, M1/M5, BASE/TURBO, FAR, Stage 1/2, trigger, margem, overshoot, timeout, gestão financeira, Magic ou sessões. A diferença estrutural é a expansão dos includes, com comentários de origem. Isso demonstra identidade do código efetivo, não uma nova medição de desempenho da estratégia.

## Testes executados

```sh
python3 tools/consolidate_scalper1995.py --check
python3 tests/test_consolidation.py
```

**9 métodos aprovados, zero falhas e zero skips.** Log: `reports/consolidation_validation.log`. Um agente separado produziu `reports/CONSOLIDATION_INDEPENDENT_AUDIT.md` usando expansor próprio, sem depender do gerador para a comparação.

A prova por pré-processador usa `g++ -E -P`, somente para expandir guards/includes/macros em cópias temporárias. Nessas cópias, os dois includes oficiais e as diretivas `#property` são retirados de ambos os lados; sua igualdade é conferida separadamente no arquivo final. Nenhum fonte protegido é alterado. **Pré-processamento não compila o EA, não verifica tipos/overloads/APIs MetaTrader e não é compilação MQL5.** A igualdade das referências prova que não foram introduzidas dependências próprias ausentes, mas não certifica a resolução nativa de todos os símbolos da biblioteca padrão nem eventuais problemas herdados do compilador/plataforma.

O gerador é determinístico e exige os hashes da revisão corrigida: recusa entradas diferentes em vez de consolidar silenciosamente uma versão anterior ou outra revisão. `--check` não escreve arquivos. O modo de geração também recusa sobrescrever uma COMPLETA existente com conteúdo diferente.

## Compilação e transferência

**COMPILACAO_NATIVA_NAO_VERIFICADA**

A verificação nesta máquina continua sem MetaEditor, terminal MT5 ou Wine disponíveis no PATH. Não foi executada compilação nativa; não existe resultado de erros/warnings MetaEditor a declarar. Replay e homologação também não foram executados nesta consolidação.

Baixe pelo GitHub somente `RemoraScalper1995_Weis1996_COMPLETA.mq5`, coloque-o em `MQL5/Experts` da instalação MT5 e abra esse arquivo no MetaEditor para compilar. Não é necessário transferir a pasta `include` do projeto. A instalação MT5 deve fornecer suas bibliotecas oficiais `Trade/*.mqh` normalmente.

O arquivo está integral e preparado estruturalmente para submissão ao compilador; não é uma afirmação de compilação bem-sucedida, homologação ou prontidão operacional.
