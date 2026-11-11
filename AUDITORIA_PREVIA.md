# Auditoria prévia — reconstrução controlada 1.995

Este registro foi preparado antes da edição estratégica da candidata. O original é preservado; nenhuma comparação com BOOK 1.125 substitui o contrato desta entrega.

## Identidade verificada

| Item | Caminho | SHA-256 |
|---|---|---|
| Original fornecido | `/workspace/eu/eu1995` | `2479ed8e5c9189438d787be1e804abbd95f9e1c06e01042e560251e64ef67fc5` |
| Especificação mestre (726 linhas) | `/workspace/eu/comando para a atualização do código` | `460617a86e17b32816458e7eea299469b01daaef0e30af277da094098e43db7a` |

O original possui 9.065 linhas. A referência `Bf/main:1995`, obtida pelo agente principal, tem blob Git `a764baec7f716ad893ee82ae807d91e2c45f3986` e conteúdo idêntico. O cabeçalho herdado menciona candidatas antigas e M3; a identidade por bytes e os defaults efetivos M5/M1 prevalecem sobre esses comentários. O módulo Weis verificado pelo agente principal é `Bf/codex/remora-matriz-objetiva:include/ObjectiveMatrix.mqh`, blob Git `e0bacb9fa1e003ddb57c658c9cc8860e208cfbfc`. Blob Git SHA-1 não é SHA-256 do arquivo.

## Fronteiras e inventário

| Área original (linhas) | Decisão |
|---|---|
| POC: enum 76; inputs 162–164; struct 234; snapshot 268–293; reset 1560–1593; cálculo 1723–1819; matriz 2177–2289 | Remover motor e consumidores exclusivos; substituir evidência C1 por Weis verificada. |
| Weis por M1: RebuildWeisCache 1822; ComputeLiveWaveO1 1879 | Substituir aquisição/evidência, sem portar arquitetura completa 1.996. |
| VWAP, sigma, macro e C2/C3/C4/C5 | Preservar fórmulas, defaults, timeframes e confluências. |
| EvaluateMatrix 3472–3640 | Preservar seleção e ROUTE_CONFLICT_BLOCK; telemetria POC perde função. |
| Stage 2 3647–3840; guard final Weis 1488–1489 | Adaptar ambos os consumidores do motor antigo, sem renovar timeout ou trigger. |
| SendOrder 3276–3444 | Protocolo financeiro protegido: sizing real, margem, preço executável, stops, overshoot, journals e despacho. |
| FARBeforeDecision 918; FARCaptureArm 3627 | Preservar FAR e extremos de região compartilhados. FAR não deve depender da POC. |
| EOD 3853–3952; BE/progressão 4435–5050; requests/exposição 5074–5232; identidade/contabilidade 5255+ | Preservação literal sempre possível; nenhum veto analítico pode impedir gestão de posições. |
| CSV Trades e journals | Compatibilidade histórica; nova telemetria em arquivo próprio. |

## Riscos demonstráveis antes da edição

1. Há duas revalidações da Weis antiga: ProcessArmedSignal em 3735 e EntryDispatchGuard em 1488. Trocar uma só cria dependência incompatível oculta.
2. `wwValid` governa novas matrizes, hard contradiction e observação read-only. Esses gates devem refletir somente a disponibilidade técnica da nova evidência. EOD, BE e reconciliação já precedem os gates em OnTick e precisam continuar independentes.
3. A região dos últimos candles serve a FAR/trigger legado; não é sinônimo de janela POC descartável.
4. ARMED imprime `0.00 lots` porque o Stage 1 deliberadamente não calcula lote (3536, 3630). Não é falha financeira; o diagnóstico deve indicar quantidade ainda não calculada.
5. Limpeza de ARMED por horário em OnTick 4288 e OnTimer 4384 não atualiza motivo nesse ponto; ResetArmedSignal já emite SIGNAL_END (1605), mas pode conservar o último motivo em vez de explicar o encerramento por horário. A auditoria precisa distinguir esses casos.
6. `PersistEconomicMarker` compara bytes escritos com 25 para literal ASCII de 27 bytes com CRLF; a investigação/correção mínima deverá ser isolada e seus testes nativos distinguidos dos testes locais de contrato.
7. Dados incrementais precisam preservar múltiplos negócios no mesmo milissegundo e fronteiras inclusivas do CopyTicksRange. Bid/Ask sozinho não é negócio, e o último tick não garante cobertura de todos os negócios.
8. Métrica por eventos de preço não equivale à eficiência por negócio. Não substituir `eventPath`, congelamento no extremo ou `drawdown < eventStep` por aproximações.

## Evidências e limites

A especificação foi lida integralmente. A leitura integral do fonte foi distribuída por segmentos entre agentes de auditoria, sem omitir os blocos financeiros. Este arquivo inventaria riscos e escopo; não prova regressão dinâmica, compilação ou qualidade financeira. Status inicial: `COMPILACAO_NATIVA_NAO_VERIFICADA`; `REPLAY_NAO_VERIFICADO`.
