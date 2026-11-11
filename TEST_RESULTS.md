# Testes e limites de aceite

Comando reproduzível atual: `python3 tests/run_all.py`, na raiz. O runner interrompe e preserva o exit status do primeiro comando que falhar.

**Revisão dirigida posterior à entrega-base85be544: 82 verificações aprovadas, zero falhas e zero skips.** São as71 verificações anteriores, mais9 métodos de epoch e2 de MaxBody. Saída consolidada atual: `reports/review_validation.log`. Inclui um controle negativo que refuta o processo anterior: uma falha esperada desse processo é verificada como prova do defeito, não ocultada. O kernel/engine/lifecycle continuam com os mesmos bytes; somente o encerramento por epoch alterado foi corrigido no EA. Ver `reports/REVIEW_DELIVERY.md`, `reports/REVIEW_EPOCH.md` e `reports/REVIEW_MAX_BODY.md`.

O registro abaixo descreve a entrega-base e sua execução histórica, preservada em `reports/validation.log`; não substitui o log atual.

**Entrega-base: 71 verificações locais aprovadas, zero falhas, zero skips**: 25 casos do kernel numérico, 23 do adaptador de negócios, 2 métodos da telemetria, 13 métodos de preservação estática e 8 métodos do marcador econômico. A identidade literal do kernel contra a referência também foi conferida. Uma verificação pode conter várias asserções; este total não é uma contagem de operações, sinais reais ou cenários MT5 executados.

| Camada | Evidência executada | Limite |
|---|---|---|
| Weis | Núcleo literal compilado em C++17; ABS/CONT simétricos, esforço, eficiência por eventos, rejeição, baseline, drawdown estrito, conflitos e causalidade | Não compila EA completo nem valida retorno financeiro |
| Ingestão | Corpo real do adaptador compilado com mocks de broker/tempo/arrays; 23 cenários | Não prova completude de feed real nem latência de CopyTicksRange |
| Telemetria | Helper real com shim MQL; schema, fila, perdas, escrita e vínculo de IDs | Não são logs de ordens reais |
| Preservação | Comparação literal de funções/blocos, inputs, schemas, remoção POC e ordem de gestão financeira | Não é equivalência global das trajetórias |
| Marcador | Função exata, mocks MQL e arquivos temporários reais; escrita, flush, falhas e reinício em processo separado | Não substitui recovery completo MT5 |

## Matriz da seção 17 do comando mestre

| Grupo exigido | Estado real |
|---|---|
| A.1–A.5 ABS | Cobertos deterministicamente no kernel: rejeição suficiente, falta de rejeição, progresso eficiente, esforço insuficiente e relógio/extremo futuro |
| B.1–B.5 CONT | Cobertura numérica: progresso/eficiência/volume, mínimo, retração `< eventStep`, reversão contemporânea, baseline insuficiente; integração do ARMED em MT5 pendente |
| C.1–C.2 conflitos/neutro | Conflito CONT com ABS anterior e volume sem prova exercitados no kernel; sem prioridade artificial |
| C.3 macro discordante | Fórmula e gate preservados literalmente; diagnósticos inspecionados, execução do EA pendente |
| C.4 ARMED/timeout/trigger | Funções de trigger e timeout preservadas literalmente; revalidação adaptada inspecionada, execução MT5 pendente |
| C.5 ABS anterior | Evidência congelada da onda anterior exercitada no kernel; snapshot fechado isolado do próximo negócio no adaptador |
| D.1–D.5 POC | Busca lexical e comparação estática: motor/inputs/consumidores removidos, nenhum fallback `true`; campos históricos vazios |
| E.1 mesmo ms | Multiplicidade de negócios distintos e idênticos, append na fronteira, prefixo reescrito/removido: exercitados |
| E.2–E.4 lacuna/reconnect/reinício | Histórico indisponível não avança cursor; intervalos vazios não inventam volume; reconnect e warmup sem sinal retroativo exercitados; lacuna não reportada pelo broker não é detectável pela API aqui |
| E.5–E.6 volume | Ausente/inválido/fora grade rejeitado; fontes inteira e real suportadas separadamente; mistura rejeitada atomicamente |
| E.7–E.8 contrato/sessão | Mudança de símbolo e dia reinicia análise; nenhum gate D1 importado; cenários antes09 e depois18:25 exercitados |
| E.9 fragmentação | Volume total, grossPath/eventPath e CONT conservados em fixtures; ABS tem limitação herdada de peakVolume no primeiro novo extremo, documentada em WEIS_INTEGRATION |
| E.10 não retroagir | Warmup, catchup e fechamento antes do próximo negócio exercitados; histórico anterior revisado invalida prova, não recria sinal passado |
| F.1–F.8 preservação | Provas literais de VWAP/sigma/C2–C5/macro/BASE–TURBO/FAR/gatilhos/financeiro; comparação numérica integrada com mesmo feed MT5 pendente |
| G.1–G.11 financeiro | Não executados em MT5: aceitação/fill, rejeição, incerteza, parcial, reinício após envio, BE pendente, posição estrangeira, journal, EOD, histórico indisponível, ausência de duplicação. Harness do marcador não substitui esses casos |

## Casos que refutaram versões intermediárias

- **Marcador original:** escrita completa de 27 bytes e flush retornavam falso pela comparação com25. Reproduzido; candidata corrigida exclusivamente para27 no commit financeiro separado. O original foi preservado.
- **Sessão indevida no adaptador:** a auditoria encontrou uso dos horários D1 como origem/limite da Weis. Corrigido para calendário diário já usado pelo EA, sem gate de entrada novo. Controles negativos em cópias temporárias com origem09 e cap18:25 fizeram os novos casos antes09/depois18:25 falharem. Adaptador final passou23 casos.
- **Fixture incoerente:** primeira execução de teste de fechamento falhou porque SymbolInfoTick simulado dizia volume1 e o histórico dizia volume13 para o mesmo negócio. A checagem de identidade rejeitou corretamente. Fixture corrigida para o registro real do histórico; guard e asserções foram mantidos.
- **Diagnósticos macro/epoch da entrega-base:** a primeira revisão corrigiu apenas os registros. A revisão dirigida posterior demonstrou que epoch diferente era terminal, embora continuasse armado. O código agora encerra essa intenção antes de tick/rompimento/rearme; com o mesmo epoch, timeout e espera transitória continuam originais. Nenhum protocolo financeiro foi flexibilizado.

## Comparação controlada ainda sem amostra operacional

| Medida | Original1.995 | Candidata sem POC |
|---|---|---|
| Candidatos/C1 aprovado e rejeitado/conflitos/C2–C5/macro/FAR | Não medido em feed real | Não medido em feed real |
| ARMED/expirados/triggers/tentativas/aceitos/fills | Não medido | Não medido |
| Resultado líquido/custos/expectativaR/drawdown/OOS WIN–WDO ABS–CONT | Não avaliado | Não avaliado |

Nenhum dado ausente é zero. Os contadores devem ser obtidos de execuções com mesmos dados e configuração, separando as categorias acima, antes de avaliar a estratégia. Não houve otimização de parâmetros.

`COMPILACAO_NATIVA_NAO_VERIFICADA` — sem erros/warnings nativos conhecidos porque MetaEditor não foi executado.

`REPLAY_NAO_VERIFICADO` — sem sessão real de Strategy Tester ou replay de ticks de mercado. P95/P99/máximo de serviço Weis/Stage1/Stage2 são instrumentados em rings de128 amostras e emitidos em ENGINE_METRICS; não foram medidos sob carga real. História registra custo da última consulta e atraso do último negócio; não há promessa preemptiva de CPU/memória.

Aceite funcional completo e homologação permanecem pendentes. Não há alegação de vantagem estatística ou prontidão para produção.
