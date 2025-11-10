# GPU_WaveViz_Solo.mq5 (runtime)

## Visão geral
- Espelho runtime do indicador solo de wave, que submete jobs diretamente ao `GpuEngineClient.dll` para reconstruir a wave e os ciclos sem o EA Hub.

## Papel no runtime
- Fornecido às estações finais e agentes via links criados pelos scripts de setup; nunca editar em produção – sincronize a versão `Dev/Indicators/GPU/GPU_WaveViz_Solo.mq5`.
- Continua exigindo a presença de `GPU_WaveViz/ZigZag.mq5` para habilitar os modos de alimentação baseados em pivôs.

## Integração e requisitos
- Mesmos parâmetros de entrada da versão de desenvolvimento (FFT window, masks, presets Kalman, HUD).
- Requer pipeline atualizado (`Build.ps1` + watchdog) para que `GpuEngineClient.dll` esteja sincronizado na árvore runtime/Include & runtime/bin.
