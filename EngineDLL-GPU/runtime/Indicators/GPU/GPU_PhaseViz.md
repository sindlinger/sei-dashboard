# GPU_PhaseViz.mq5 (runtime)

## Visão geral
- Cópia sincronizada do indicador `Dev/Indicators/GPU/GPU_PhaseViz.mq5`, responsável por exibir fase, amplitude, período, ETA e demais métricas provenientes da WaveSpec GPU.
- Utiliza os buffers compartilhados definidos em `Include/GPU/GPU_Shared.mqh`, que são atualizados pelo cliente GPU em execução (EA Hub ou indicadores solo).

## Papel no runtime
- Esta versão é lida diretamente pelos terminais MetaTrader linkados via `SetupRuntimeLinks.ps1`; alterações devem ser feitas apenas na árvore `Dev/` e propagadas pelo watchdog.
- Mantém separação de janelas (`indicator_separate_window`) e 12 buffers, idênticos à versão de desenvolvimento.

## Integração e requisitos
- Requer que a instância runtime possua DLLs/estruturas atualizadas (resultantes de `Build.ps1`) e que os links estejam corretos para `GpuEngineClient.dll`.
- Depende do produtor (geralmente `runtime/Experts/GPU/GPU_EngineHub.mq5` ou indicadores solo) para inserir dados em `GPU_Shared`.
