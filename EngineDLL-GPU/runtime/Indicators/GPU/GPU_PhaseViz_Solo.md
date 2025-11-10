# GPU_PhaseViz_Solo.mq5 (runtime)

## Visão geral
- Replica exata do indicador autônomo descrito em `Dev/Indicators/GPU/GPU_PhaseViz_Solo.mq5`.
- Conecta-se diretamente ao `GpuEngineClient.dll` instalado na instância runtime para gerar buffers de fase/kalman/countdown sem necessidade do EA Hub.

## Papel no runtime
- Arquivo consumido pelos terminais em produção; qualquer manutenção deve ocorrer em `Dev/` e ser propagada por `WatchdogFiles_dev_to_runtime.py`.
- O indicador continua esperando que `GPU_WaveViz/ZigZag.mq5` esteja presente na mesma árvore runtime para habilitar os modos de feed ZigZag.

## Integração e requisitos
- Requer junctions válidos para `GpuEngineClient.dll` e demais DLLs na pasta física `AgentsFiles-to-tester_folder_terminals/` (nunca `%APPDATA%\MetaQuotes\Terminal`).
- Mantém todos os parâmetros de entrada (FFT, hop, máscaras, presets Kalman, layout HUD); recomenda-se revisar as configurações após copiar o template para o runtime.
