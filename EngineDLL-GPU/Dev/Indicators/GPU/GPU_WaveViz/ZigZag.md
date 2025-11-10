# ZigZag.mq5

## Visão geral
- Cópia do indicador ZigZag padrão da MetaQuotes (licença 2000–2025) distribuída junto do projeto para servir como dependência offline.
- Utilizado pelos indicadores “solo” (`GPU_PhaseViz_Solo.mq5`, `GPU_WaveViz_Solo.mq5`) quando os modos de alimentação exigem pivôs ZigZag gerados localmente.

## Organização interna
- Implementação original do ZigZag clássico:
  - Define três buffers (`ZigZagBuffer`, `HighMapBuffer`, `LowMapBuffer`).
  - `OnInit` registra os buffers, configura o nome curto e o valor vazio.
  - `OnCalculate` procura máximas/mínimas recentes usando `Highest`/`Lowest`, aplica `InpDeviation` e `InpBackstep`, substitui extremas anteriores e desenha segmentos via `DRAW_SECTION`.
- Nenhuma modificação específica do WaveSpecGPU foi adicionada; o arquivo é mantido íntegro para preservar consistência com o terminal MetaTrader 5.

## Integração com o GpuEngine
- Não consome o `GpuEngineClient`. É utilizado indiretamente pelos indicadores solo para gerar a série `work_series` que alimenta os jobs GPU.
- O caminho relativo (`GPU_WaveViz/ZigZag.mq5`) é passado para `iCustom`, portanto o arquivo deve residir na mesma pasta dos indicadores que o referenciam.

## Requisitos e uso
- Inputs padrão do ZigZag: `InpDepth`, `InpDeviation`, `InpBackstep`; os indicadores solo repassam esses valores via parâmetros externos.
- Deve estar presente em ambas as árvores `Dev/Indicators/GPU/GPU_WaveViz/` e `runtime/Indicators/GPU/GPU_WaveViz/` para que o `iCustom` funcione tanto no ambiente de desenvolvimento quanto no runtime.
- Não requer GPU; roda apenas na CPU do terminal.
