# Revisão dirigida — Inp_ABS_MaxBodyPts_WIN/WDO

Revisão do ponto 3 solicitado antes da homologação. Referência de entrega: `85be544`, original `eu1995` preservado, candidata `RemoraScalper1995_Weis1996.mq5`. Esta revisão não altera fonte, filtros, inputs ou defaults.

## Resultado

Os inputs **não participam mais da elegibilidade de C1 ABS nem de outro predicado de entrada na candidata**. Existe uma perda funcional real: variar um valor positivo de MaxBody deixou de habilitar/desabilitar o subtipo original `absStallStrict`.

Eles **ainda participam de uma decisão de configuração**, pois `Validate1995Inputs()` rejeita `!Positive(gABS_MaxBodyPts)`. Portanto, não é correto afirmar que não têm efeito algum no programa: zero, negativo ou valor não finito pode impedir a inicialização. Os nomes/defaults continuam presentes na interface e são resolvidos por ativo, copiados ao snapshot e impressos no log EFFECTIVE. Esses usos não restabelecem a função estratégica removida.

## Todos os consumidores e sua função

| Caminho | Original eu1995 | Candidata |
|---|---|---|
| Declarações | `Inp_ABS_MaxBodyPts_WIN=60.0`, `WDO=2.0` | Nome/tipo/default/ordem relativa preservados |
| Resolução por família em OnInit | `gABS_MaxBodyPts=gIsIndexFamily?...WIN:...WDO` | Literalmente preservada |
| Validação de configuração | `!Positive(gABS_MaxBodyPts)` impede inicialização | Preservada; continua decisória na inicialização |
| Snapshot | `s.maxBody=gABS_MaxBodyPts`; reset em zero | Preservado, mas sem leitura decisória posterior |
| Predicado numérico | `s.c1_body_ok=(s.candleBody<=s.maxBody)` | Removido |
| Consumidor estratégico direto | `absStallStrict=windowsValid && pocState==POCS_NO_DISPLACEMENT && c1_body_ok` | Removido com o contexto POC |
| Consumidor estratégico indireto | `absPocContextOk=absDivergence || absStallStrict || absFollowingReaction`; `c1=c1_effort_ok && absPocContextOk` | Substituído por classificação Weis confirmada e concordância de direção |
| CSV histórico | ABS_MAX_BODY, ABS_BODY_OK, ABS_STALL_STRICT preenchidos | Cabeçalhos mantidos; células aposentadas vazias |
| Print EFFECTIVE | ABSbody mostra valor resolvido | Preservado; indica configuração, não prova de filtro ativo |
| Kernel/engine Weis | Não existiam como includes | Nenhum consumidor MaxBody; o classificador usa esforço, progresso, eventPath, eficiência e rejeição |

No original, a cadeia decisória está em `eu1995:2256`, `2265–2276`; resolução em `4132`, validação em `4013`. A simples cópia para `s.maxBody` na candidata não cria dependência em C1: os únicos dois acessos `s.maxBody` restantes são atribuições (reset e captura).

## Semântica original: não havia limite universal de corpo em ABS

O predicado de corpo era obrigatório **somente no contexto POC de ausência de deslocamento**. `absDivergence` e `absFollowingReaction` podiam aprovar C1 independentemente desse predicado. Logo, inserir agora `candleBody<=MaxBody` como AND geral de ABS criaria um filtro adicional e modificaria também casos que o original não limitava dessa forma.

A candidata atual usa:

```cpp
s.c1=s.wwok && (s.weis.classification==3 || s.weis.classification==4) &&
   s.weis.dir==s.dir;
```

Não há corpo máximo nesse predicado. `OMAbsEvidence` exige a tentativa de onda válida, baseline, esforço congelado no extremo, progresso mínimo, baixa eficiência e rejeição posterior mínima. Esses requisitos são diferentes do filtro de corpo do candle; não há prova de equivalência semântica entre eles.

## Comparação com o comando mestre

A seção 2 autoriza remover filtros exclusivamente associados à POC e adequar C1 ABS/CONT. A seção 4 inclui explicitamente `absStallStrict` e `absPocContextOk` no inventário de remoção, com obrigação de verificar seus consumidores. A seção 3 adverte que a troca de C1 altera decisões de entrada. Isso sustenta tratar a perda do subtipo de stall e do seu limite de corpo como **consequência documentada da substituição autorizada de C1**, não como preservação integral da função MaxBody.

A mesma seção 2 proíbe mudar outros requisitos de entrada, salvo dependência inevitável demonstrada da remoção. Nesta investigação, não foi encontrado consumidor estratégico de MaxBody fora do subtipo POC eliminado. Preservar nome/default/validação não prova preservação dessa funcionalidade, mas tampouco autoriza reinterpretá-la como novo filtro universal da Weis.

A fronteira deve ser descrita assim: critérios restantes e gestão protegida preservados; C1 POC substituído, incluindo a perda do controle estratégico MaxBody ligado a `absStallStrict`. Se o aceite futuro exigir um limite de corpo independente da POC, isso precisa de uma regra adicional explícita e de teste próprio. Nenhuma regra desse tipo foi inventada ou implementada nesta revisão.

## Testes executados e resultado

Comando: `python3 tests/test_review_max_body.py`.

**2 métodos aprovados, zero falhas e zero skips.** Um deles compila em C++17 os **predicados extraídos dos próprios fontes**, sem reescrever o classificador. Outro rastreia declarações, resolução, gate de inicialização, ausência de consumidor nos includes e os dois acessos apenas de escrita do campo `s.maxBody` na candidata.

Casos efetivamente executados no harness:

| Dados controlados | Resultado original | Resultado candidata |
|---|---|---|
| Esforço suficiente, POC sem deslocamento, corpo61, MaxBody60 | C1 falso | C1 depende da prova Weis, não desse limite |
| Mesmo caso original, apenas MaxBody70 | C1 verdadeiro | Classificação Weis congelada não muda ao variar o limite positivo |
| POC divergente com corpo acima do limite | C1 verdadeiro por divergência | Nenhum AND geral foi acrescentado |
| POC seguindo na direção de reação com corpo acima do limite | C1 verdadeiro por following-reaction | Nenhum AND geral foi acrescentado |
| Prova Weis ABS válida, MaxBody variado em0.5/60/70/1000 e corpo0/61/10000 | Não é uma comparação de sinais equivalentes | C1 permanece verdadeiro enquanto a prova/direção permanecem válidas |
| Prova Weis ausente, direção discordante ou WW indisponível | Não usado para inferir a nova regra | C1 falso, mesmo ao ampliar MaxBody |

A validação positiva dos inputs foi conferida no texto da função real; não foi executada a inicialização completa do terminal. O harness mostra o vínculo causal isolado do predicado, não um replay da matriz/EA, aceitação de ordem ou resultado financeiro.

`COMPILACAO_NATIVA_NAO_VERIFICADA` e `REPLAY_NAO_VERIFICADO` permanecem. Estes resultados não homologam a candidata.

## Diff deste ponto

Nenhuma alteração em `.mq5`, includes, defaults ou mecanismos. Adicionados somente este relatório e `tests/test_review_max_body.py`. A revisão torna explícita uma perda funcional já presente na entrega, em vez de ocultá-la por nomes de inputs preservados.
