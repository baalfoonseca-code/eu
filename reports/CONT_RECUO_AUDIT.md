# Auditoria independente — recuo CONT separado da trajetória Weis

Base de comparação: `e98b9bbb2e36f48d1d32ada196d5d3c96741357d`, Scalper 1.995 reconstruída. A auditoria não editou o fonte, o kernel, o engine, o build ou os testes. Este relatório registra inspeção e comparação estática; os resultados dos cenários executados ficam no relatório de testes da entrega.

## Mudança operacional delimitada

O kernel local `include/Weis1996Kernel.mqh` continua sendo um derivado privado da 1.995, com guard `REMORA_1995_WEIS_1996_KERNEL_MQH`. A correção acrescenta `OMConfig.contMaxRecuo` e troca somente o último predicado CONT de `drawdown<c.eventStep` para `drawdown<c.contMaxRecuo`.

`include/Weis1996Engine.mqh` acrescenta, ao final dos sete inputs Weis existentes, os inputs inteiros `Inp_CONT_MaxRecuoTicks_WIN=2` e `Inp_CONT_MaxRecuoTicks_WDO=2`. `WWConfiguration` resolve a família reconhecida pelo EA e multiplica o valor correspondente por `gTickSize`, que é o tamanho real de tick já resolvido em `OnInit`. WIN/IND usam a família índice; WDO/DOL usam a família dólar. A atribuição de `eventStep=Inp_PathEventTicks*gTickSize` permanece inalterada.

A comparação de funções com a base encontrou:

| Arquivo | Funções inventariadas | Mudança executável |
|---|---:|---|
| EA modular | 315 | Nenhuma; somente comentário em `ComputeMatrixSnapshot` foi atualizado |
| Kernel local | 7 | Somente `OMClassify`, no predicado do recuo CONT |
| Engine local | 20 | Somente `WWConfiguration` e `WWValidateInputs` |

O acréscimo do campo de configuração e dos dois inputs é explícito, fora dos corpos das funções. Nenhuma função foi removida ou acrescentada nos dois módulos numéricos. Os 77 inputs existentes preservam nome, tipo, default e ordem relativa; a unidade efetiva passa a 79 inputs após incorporar os dois novos parâmetros.

## Mapa dos consumidores

| Consumidor | Efeito após a correção |
|---|---|
| `WWConfiguration.eventStep` | Continua vindo exclusivamente de PathEventTicks e tick real |
| `OMWavePush(...eventStep...)` | Formação, eventPrice, eventPath e congelamentos de extremo permanecem literais |
| `WWApplyBatch` | Passa o mesmo eventStep à formação de ondas; não lê contMaxRecuo |
| `WWValidateInputs` | Conserva a validação anterior de amostragem e reversão; acrescenta a validação dos novos parâmetros |
| `OMClassify` | O recuo CONT passa a usar apenas contMaxRecuo; comparação estrita `<` preservada |
| `OMAbsEvidence` | Corpo literalmente idêntico; não lê contMaxRecuo |
| `LiveWeisForArmed` e `WWLiveWave` | Direção/esforço vivos de Stage 2 permanecem idênticos e não consomem contMaxRecuo |
| `EntryDispatchGuard` e `ProcessArmedSignal` | Inalterados, inclusive invalidação por epoch, timeout, gatilhos e proteções |

Não foi acrescentada relação entre tolerância de recuo e amostragem/reversão. As restrições existentes de amostragem — PathEventTicks positivo e reversão suficiente para seu passo — continuam referentes ao mecanismo original, não limitam o novo recuo.

## Validação dos parâmetros

Os dois novos inputs devem ser positivos. Seus produtos pelo tick devem ser finitos, e o limite escolhido precisa ser positivo e finito. Isso rejeita configuração impossível de representar sem inventar confirmação ou corrigir silenciosamente o valor.

Não foi imposto teto estratégico, limite igual à reversão, igualdade com PathEventTicks ou qualquer ordenação entre os dois mecanismos. O limite inerente ao tipo `int` não foi transformado em limite estratégico adicional. A validação examina ambos os valores declarados, incluindo o da outra família, para rejeitar configuração inválida de forma explícita.

## Equivalência padrão e fronteiras

Com PathEventTicks no default 2 e os dois novos inputs em 2, o limite anterior e o novo são a mesma expressão numérica `2*gTickSize`. Todo o restante do classificador e da formação de ondas permanece igual. A comparação estrita significa que recuo exatamente igual ao limite continua rejeitado; zero ou um tick não é barrado por esse predicado quando o limite é dois ticks e os demais critérios estão satisfeitos.

Essa equivalência não deve ser estendida a presets antigos com PathEventTicks diferente de 2: nesses presets, o limite antigo variava junto da amostragem. Após a correção, para reproduzir o limite antigo de um preset específico, o novo parâmetro da família precisaria receber o antigo número de ticks. Não houve migração automática de presets ou modificação de defaults.

Aumentar somente o novo limite não altera os negócios processados, eventPath, eficiência, esforço, baseline, pico ou rejeição. Pode alterar elegibilidade CONT e resultados posteriores. `OMAbsEvidence` permanece matematicamente igual, mas a classificação final ABS não é prometida como invariável em todos os cenários: uma CONT recém-elegível pode coexistir com ABS anterior e produzir o conflito já existente de `OMClassify`. Essa consequência posterior é preservação da política de conflito, não alteração da evidência ABS ou prioridade arbitrária.

## Isolamento da Scalper Bands 1.996 e do financeiro

O inventário de fontes executáveis do checkout contém os dois arquivos 1.995, seus três módulos locais e a referência vendorizada. Nenhuma Scalper Bands 1.996 executável foi encontrada neste checkout. Os consumidores de Weis1996Kernel/Engine do projeto são o EA modular 1.995 e a incorporação correspondente no monolítico; o módulo de referência não inclui esses arquivos locais.

`references/ObjectiveMatrix.e0bacb9.mqh` continua byte a byte igual à base e conserva o blob Git `e0bacb9fa1e003ddb57c658c9cc8860e208cfbfc`, inclusive a condição antiga `drawdown<c.eventStep` e seu `OMRevalidate` original. Ela não é editada nem substituída pelo kernel adaptado. Não foi feita alteração no repositório remoto Bf ou em outra branch/projeto.

Também foram conferidos como byte-idênticos à base:

- `eu1995`: SHA-256 `2479ed8e5c9189438d787be1e804abbd95f9e1c06e01042e560251e64ef67fc5`.
- `references/ObjectiveMatrix.e0bacb9.mqh`: SHA-256 `9bd44f13e61845be3c490a802035667da5ff0cb491f9b5a6bb127722b09a1b08`.
- `include/SignalLifecycle1995.mqh`: SHA-256 `500338661e5f731dbecfd31ecc1194e0cdfd89105afcfd6ea12a318acd097504`.

A comparação das 315 funções do EA modular não encontrou mudança executável. Isso inclui C2–C5, bandas, VWAP, sigma, macro, BASE/TURBO, Stage 2, FAR, SL/TP, lotes, Magic, execução, BE/EOD, persistência e recuperação. Não foi reintroduzida POC ou Volume Profile.

## Conferência final do build e dos resultados

A alteração de origem foi isolada no commit `0ecac27d81f8ebbf887d936305543af78122a019`: apenas os dois módulos numéricos locais e o comentário do EA modular. O processo oficial foi atualizado para fixar os hashes desse commit e regenerou o monolítico. O modo `--replace-generated` só admite substituir um arquivo anterior quando o SHA-256 informado coincide com seu conteúdo; não fornece permissão para alterar os fontes de origem. O comando `python3 tools/consolidate_scalper1995.py --check` foi executado pela auditoria e retornou PASS.

O monolítico final tem **9525 linhas e 404336 bytes**, SHA-256:

```text
29802b83ed4952980910b39d546617cdb0da4c7adf1ef84bd670b98ca1be0e0a
```

Uma expansão recursiva independente do gerador, considerando cada módulo protegido por guard uma única vez, conferiu **78099 tokens ativos idênticos**, **353 corpos de funções literalmente iguais** entre a unidade modular atual e a monolítica e **79 inputs na mesma ordem e com os mesmos defaults**. Assim, não há correção exclusiva aplicada manualmente ao monolítico e ausente dos arquivos de origem.

O término e as contagens do log `reports/cont_recuo_validation.log` foram inspecionados: **101 verificações locais aprovadas**, sem falha ou skip no resultado final — 25 kernel, 23 adaptador, 2 lifecycle, 13 preservação, 8 marcador financeiro, 9 epoch, 2 MaxBody, 10 do desacoplamento CONT e 9 da consolidação.

Os dez métodos de `tests/test_cont_recuo.py` compilam os corpos reais do kernel anterior, kernel atual e configuração/validação do engine com serviços primitivos simulados. O log registra 140 comparações diferenciais de decisões nos defaults. Também registra os cenários de fronteira estrita, família WIN/WDO, independência da amostragem, aumento isolado de tolerância, evidência ABS ativa/anterior idêntica, conflito posterior preservado e validação positiva sem teto ou dependência com PathEventTicks. A inspeção não transforma esses testes portáveis em execução nativa de MT5.

A referência 1.996, o original `eu1995` e o lifecycle foram novamente conferidos byte a byte contra a base depois da geração. Não foi identificado desvio operacional adicional no build auditado.

## Limites da conclusão

A inspeção demonstra a restrição do diff e a ausência de dependência nova entre os mecanismos. Identidade de funções preservadas não substitui uma sessão de negociação ou recovery real. Os testes portáveis da entrega precisam manter separados os cenários de default, fronteira, família e independência, sem descrever mocks como MT5 nativo.

`COMPILACAO_NATIVA_NAO_VERIFICADA`

Replay real e homologação não foram demonstrados nesta auditoria. Nenhum P1 adicional foi identificado no diff de origem inspecionado.
