# ZigZag.mq5 (runtime)

## Visão geral
- Mantém a mesma implementação do ZigZag padrão copiado em `Dev/Indicators/GPU/GPU_WaveViz/ZigZag.mq5`.
- Suporte obrigatório para os indicadores solo no ambiente runtime quando estes utilizam os modos `Feed_ZigZag*`.

## Papel no runtime
- Distribuído automaticamente para as instâncias MetaTrader a partir das sincronizações feitas pelo watchdog.
- Deve permanecer intocado; qualquer atualização deve acontecer na cópia em `Dev/` e ser propagada.

## Integração e requisitos
- É carregado via `iCustom` com caminho relativo `GPU_WaveViz/ZigZag.mq5`.
- Inputs `InpDepth`, `InpDeviation`, `InpBackstep` são gerenciados pelos indicadores que o invocam.
