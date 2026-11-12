# Consolidação integral da Rêmora Scalper 1.995

Arquivo final: **`RemoraScalper1995_Weis1996_COMPLETA.mq5`**, 9525 linhas e 404336 bytes. Foi gerado integralmente, sem cortes ou pseudocódigo, a partir da revisão corrigida mais recente da branch `codex/reconstrucao-scalper-1995-weis`, commit **`0ecac27d81f8ebbf887d936305543af78122a019`**. Esta regeneração incorpora a correção autorizada do recuo CONT descrita em `CONT_RECUO_REPORT.md`; o build confere os hashes dos fontes versionados nesse commit.

SHA-256 do arquivo completo:

```text
29802b83ed4952980910b39d546617cdb0da4c7adf1ef84bd670b98ca1be0e0a
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
| Sem declarações duplicadas | Inventários sem duplicação de 353 funções, 33 tipos, 296 variáveis globais (incluindo inputs) e 79 inputs |
| Referências internas | 38 nomes de funções OM/WW/LL consumidos têm definição; tipos/globais e todos os tokens de referência são os mesmos da unidade modular expandida. Não foi introduzida referência própria nova ou ausente |
| Inputs | 79 nomes, tipos, ordem efetiva e valores padrão idênticos |
| Condições decisórias | 78099 tokens ativos iguais pela expansão independente; outro teste compara o texto efetivo produzido pelo pré-processador C, sem diferenças |
| Financeiro |Todas as 353 funções têm corpos literalmente iguais, inclusive SendOrder, sizing, OnTradeTransaction, marcador econômico, BE, EOD, journals e reconciliação |
| Última revisão |EndRevisedWeisThesis e suas chamadas em ProcessArmedSignal/OnTick/OnTimer preservadas literalmente; marcador mantém written==27 |
| Arquivos protegidos |EA modular, três módulos e eu1995 permanecem byte a byte iguais à base modular0ecac27 usada pelo build; não são modificados pela regeneração |

Na etapa de regeneração não houve alteração adicional em relação à versão modular0ecac27. Não houve reordenação de código funcional ou mudança adicional de C1–C5, ondas, ABS/CONT, VWAP/sigma, M1/M5, BASE/TURBO, FAR, Stage 1/2, trigger, margem, overshoot, timeout, gestão financeira, Magic ou sessões. A diferença estrutural é a expansão dos includes, com comentários de origem. Isso demonstra identidade do código efetivo, não uma nova medição de desempenho da estratégia.

## Testes executados

```sh
python3 tools/consolidate_scalper1995.py --check
python3 tests/test_consolidation.py
```

**9 métodos aprovados, zero falhas e zero skips.** Log atual: `reports/cont_recuo_validation.log`. A auditoria independente da regeneração está em `reports/CONT_RECUO_AUDIT.md`. `reports/consolidation_validation.log` e `reports/CONSOLIDATION_INDEPENDENT_AUDIT.md` registram a primeira consolidação, anterior a esta correção.

A prova por pré-processador usa `g++ -E -P`, somente para expandir guards/includes/macros em cópias temporárias. Nessas cópias, os dois includes oficiais e as diretivas `#property` são retirados de ambos os lados; sua igualdade é conferida separadamente no arquivo final. Nenhum fonte protegido é alterado. **Pré-processamento não compila o EA, não verifica tipos/overloads/APIs MetaTrader e não é compilação MQL5.** A igualdade das referências prova que não foram introduzidas dependências próprias ausentes, mas não certifica a resolução nativa de todos os símbolos da biblioteca padrão nem eventuais problemas herdados do compilador/plataforma.

O gerador é determinístico e exige os hashes da revisão corrigida: recusa entradas diferentes em vez de consolidar silenciosamente uma versão anterior ou outra revisão. `--check` não escreve arquivos. O modo de geração recusa sobrescrever uma COMPLETA diferente, exceto quando `--replace-generated SHA256` coincide com o hash verificado do artefato anterior. Essa opção não dispensa a verificação dos hashes dos fontes.

## Compilação e transferência

**COMPILACAO_NATIVA_NAO_VERIFICADA**

A verificação nesta máquina continua sem MetaEditor, terminal MT5 ou Wine disponíveis no PATH. Não foi executada compilação nativa; não existe resultado de erros/warnings MetaEditor a declarar. Replay e homologação também não foram executados nesta consolidação.

Transfira somente `RemoraScalper1995_Weis1996_COMPLETA.mq5`, coloque-o em `MQL5/Experts` da instalação MT5 e abra esse arquivo no MetaEditor para compilar. Não é necessário transferir a pasta `include` do projeto. A instalação MT5 deve fornecer suas bibliotecas oficiais `Trade/*.mqh` normalmente.

O arquivo está integral e preparado estruturalmente para submissão ao compilador; não é uma afirmação de compilação bem-sucedida, homologação ou prontidão operacional.
