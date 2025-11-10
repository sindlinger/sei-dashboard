# GPU_PhaseViz_Solo.mq5

## Visão geral
- Indicador “solo” que se conecta diretamente ao `GpuEngineClient.dll` para gerar fase, amplitude, contagem regressiva e demais métricas sem depender do EA `GPU_EngineHub`.
- Trabalha em dois modos de alimentação: barras de fechamento ou série derivada do ZigZag interno (arquivo `GPU_WaveViz/ZigZag.mq5`), permitindo reconstruir o sinal principal mesmo sem o Hub.
- Inclui HUD interativo, botões desenhados via objetos gráficos e sobreposições no gráfico principal para exibir linha “colada” ao preço, marcadores de turn e countdown.

## Organização interna
- **Imports**: declara todas as funções exportadas pelo `GpuEngineClient.dll` (`GpuClient_Open`, `GpuClient_SubmitJob`, `GpuClient_FetchResult` etc.) além da estrutura `GpuEngineResultInfo`.
- **Buffers do indicador**: oito buffers (`g_bufPhase`, `g_bufPhaseSaw`, `g_bufAmplitudeLine`, `g_bufKalmanLine`, `g_bufCountdownLine`, `g_bufTurnPulse`, `g_bufFrequencyLine`, `g_bufVelocityLine`).
- **Buffers auxiliares**: dezenas de arrays usados para construir frames, recuperar saídas completas (wave, preview, cycles, velocity etc.) e armazenar estatísticas do motor.
- **Sanitização**: `IsBadSample`/`SanitizeBuffer` previnem valores inválidos (`NaN`, `EMPTY_VALUE`, overflow).
- **ZigZag**: funções `EnsureZigZagHandle`, `BuildZigZagSeries` e `PrepareZigZagFrames` transformam o indicador ZigZag local em série contínua para alimentar a GPU quando `InpFeedMode` requer.
- **Parâmetros de entrada**: abrangem escolha de dispositivo, tamanho de FFT, hop, máscaras gaussianas, presets de Kalman, configuração do ZigZag e layout dos botões.

## Integração com o GpuEngine
- Abre conexão com `GpuEngineClient.Open` usando `InpGPUDevice`, `InpFFTWindow`, `InpHop` e flags derivados e armazena o handle retornado.
- Submete jobs (`GpuClient_SubmitJob`) com bits `JOB_FLAG_STFT`/`JOB_FLAG_CYCLES` e parâmetros de máscara, candidatos de ciclo e presets Kalman.
- Faz polling (`GpuClient_PollStatus`) e coleta resultados (`GpuClient_FetchResult`) preenchendo os buffers locais; optionalmente lê estatísticas (`GpuClient_GetStats`, `GetBackendName`, `IsServiceBackend`).
- Pode operar contra o serviço Windows do engine (`InpUseGpuService=true`) ou conectar-se diretamente ao DLL hospedado no terminal.

## Requisitos e flags
- `GpuEngineClient.dll` deve estar acessível no terminal MetaTrader (garantido pelos scripts `SetupRuntimeLinks.ps1` / `WatchdogFiles_dev_to_runtime.py`).
- O indicador espera CUDA habilitada, driver compatível e que o serviço/dll tenha sido compilado pelo pipeline `Build.ps1`.
- Modos ZigZag necessitam da cópia local de `GPU_WaveViz/ZigZag.mq5`; o feed usa `iCustom` com os parâmetros `InpZigZagDepth`, `InpZigZagDeviation`, `InpZigZagBackstep`.
- Flags de trabalho: `JOB_FLAG_STFT` ativa cálculo STFT/preview; `JOB_FLAG_CYCLES` solicita decomposição em ciclos.

## Uso recomendado
- Execute `GPU_PhaseViz_Solo` em contas que precisam apenas de um indicador e não desejam o EA Hub. Configure `InpFeedMode` = `Feed_ZigZagBridge` para suavização pela ponte ZigZag ou `Feed_Close` para feed direto de preço.
- Ajuste janela (`InpFFTWindow`) e hop (`InpHop`) considerando o balanço latência × resolução (e garantindo multiplidade com o watchdog configurado).
- Para operação em agentes/testes, assegure que os links para `AgentsFiles-to-tester_folder_terminals/` estejam atualizados; jamais aponte para `%APPDATA%\MetaQuotes\Terminal\<GUID>`.
