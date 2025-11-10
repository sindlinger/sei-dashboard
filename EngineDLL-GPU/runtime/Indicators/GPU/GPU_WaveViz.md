# GPU_WaveViz.mq5 (runtime)

## Visão geral
- Versão distribuída do indicador que exibe wave filtrada, ruído e até 12 ciclos a partir dos buffers de `GPU_Shared`.
- É a contraparte de produção de `Dev/Indicators/GPU/GPU_WaveViz.mq5`.

## Papel no runtime
- Disponibilizado às instâncias MetaTrader por meio de junctions configuradas pelos scripts `SetupRuntimeLinks.ps1` e `WatchdogFiles_dev_to_runtime.py`.
- Não deve ser editado manualmente; alterações vão para `Dev/` e são sincronizadas.

## Integração e requisitos
- Depende do EA `runtime/Experts/GPU/GPU_EngineHub.mq5` (ou indicadores solo) para preencher os arrays compartilhados.
- Respeita os inputs `InpShowNoise`, `InpShowCycles`, `InpMaxCycles` para controlar o desenho local.
