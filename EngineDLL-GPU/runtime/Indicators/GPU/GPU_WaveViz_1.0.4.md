# GPU_WaveViz_1.0.4.mq5 (runtime)

## Visão geral
- Implementação runtime da variante “Service Edition” que renderiza wave, preview, ruído, ciclos ranqueados por PLV, além de métricas de HUD.
- Copiada automaticamente de `Dev/Indicators/GPU/GPU_WaveViz_1.0.4.mq5`.

## Papel no runtime
- Arquivo consumido diretamente pelas plataformas MetaTrader vinculadas; manter a edição na árvore de desenvolvimento e sincronizar via watchdog.
- Disponibiliza os mesmos inputs (`InpShowPreview`, `InpShowNoise`, `InpMaxCycles`, `InpShowHud`) para configuração local.

## Integração e requisitos
- Necessita que o produtor runtime envie jobs ao serviço GPU com flags `JOB_FLAG_STFT` e `JOB_FLAG_CYCLES`, garantindo que buffers preview/cycles/plv estejam presentes em `GPU_Shared`.
- Depende dos links corretos para DLLs nas pastas físicas de agentes; certifique-se de usar `AgentsFiles-to-tester_folder_terminals/` ao configurar testers.
