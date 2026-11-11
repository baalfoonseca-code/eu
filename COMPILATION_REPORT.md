# Compilação e execução

**COMPILACAO_NATIVA_NAO_VERIFICADA**

Máquina Linux x86_64 inspecionada: MetaEditor, terminal MT5 e Wine não estão disponíveis no PATH; a inspeção inicial de /opt e /usr/local também não localizou instalação MetaTrader. Nenhuma compilação MQL5 foi executada. Não há contagem nativa de erros ou warnings a reportar.

Os testes C++ compilam o núcleo numérico literal e os adaptadores com substituições de serviços MQL por mocks; não compilam o EA completo, não verificam todos os tipos/overloads/APIs MQL e não substituem MetaEditor.

**REPLAY_NAO_VERIFICADO**

Não foram fornecidos ticks reais gravados, histórico de negócios/execuções do broker, logs de Strategy Tester ou instalação de MT5. Nenhuma ordem real foi enviada. Não foram medidos vantagem, rentabilidade, drawdown, acurácia, custos ou latência de corretora.

Para a revisão nativa, colocar `RemoraScalper1995_Weis1996.mq5` e a pasta `include` na mesma pasta de Expert Advisor, com a biblioteca padrão `Trade/Trade.mqh` e `Trade/PositionInfo.mqh` do MT5. Compilar no MetaEditor e preservar o log completo, build da ferramenta e SHA-256 da candidata. Zero erros é exigido; warnings devem ser listados e analisados. Depois executar os cenários pendentes de TEST_RESULTS.md com configuração fixa, dados e relógios controlados. Compilar não homologará a estratégia.

A versão é experimental e ainda não cumpre a aceitação funcional completa. Não ativar para produção por inferência dos testes locais.
