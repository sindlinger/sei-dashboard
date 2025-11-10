# GPU_WaveViz_Solo.mq5

## Visão geral
- Indicador autônomo que envia frames diretamente ao `GpuEngineClient.dll`, reconstruindo a wave principal sem depender do EA Hub.
- Renderiza até 24 ciclos, wave dominante, linha “perfeita” colada ao preço, contagem regressiva e HUD interativo com botões para ligar/desligar camadas.

## Organização interna
- **Imports**: mesmo conjunto de funções do cliente GPU usado pelo PhaseViz Solo (`GpuClient_Open`, `GpuClient_SubmitJob`, `GpuClient_FetchResult`, `GpuClient_GetStats` etc.).
- **Buffers plotados**: 29 buffers (`g_bufWave`, `g_bufNoise`, `g_bufCycle1`…`g_bufCycle24`, `g_bufDominant`, `g_bufPerfect`, `g_bufCountdown`).
- **Gestão de UI**: usa objetos (`ObjectCreate`) para HUD e botões definidos em `PhaseButton`-like enums, permitindo alternar camadas diretamente no gráfico principal.
- **Aquisição de dados**:
  - Constrói frames a partir do preço ou do ZigZag (via `GPU_WaveViz/ZigZag.mq5`), seguindo a mesma infraestrutura de `GPU_PhaseViz_Solo`.
  - Suporta máscaras gaussianas, seleção manual de períodos (`InpUseManualCycles`, `InpCycleMinPeriod`, `InpCycleMaxPeriod`) e filtro de candidatos.
- **Processamento**:
  - Submete jobs com flags para `JOB_FLAG_STFT`/`JOB_FLAG_CYCLES`.
  - Copia resultados individuais (wave, preview, noise, cycles, dominant/perfect, countdown, velocity, power) para buffers dedicados.
  - Sanitiza valores extremos (`GPU_SANITIZE_THRESHOLD`) antes de desenhar.

## Integração com o GpuEngine
- Requer `GpuEngineClient.dll` acessível no terminal e devidamente configurado pelos scripts `SetupRuntimeLinks.ps1` e `WatchdogFiles_dev_to_runtime.py`.
- Pode preferir o backend de serviço (`InpUseGpuService=true`) ou operar conectado diretamente ao DLL carregado pelo terminal.
- Leitura de resultados depende da estrutura `GpuEngineResultInfo` incluída no próprio arquivo.
- Publica stats (tempo médio/máximo) e backend name via `GpuClient_GetStats/GetBackendName` quando habilitado.

## Requisitos e parâmetros
- Principais entradas:
  - Configuração do job (`InpGPUDevice`, `InpFFTWindow`, `InpHop`, `InpUseManualCycles`, `InpCycleCount`…).
  - Controle de feed (`InpFeedMode` e parâmetros ZigZag).
  - Filtros de máscara (`InpGaussSigmaPeriod`, `InpMaskThreshold`, `InpMaskSoftness`, `InpMaskMinPeriod`, `InpMaskMaxPeriod`).
  - Presets de Kalman (`InpKalmanPreset` + ajustes manuais).
  - Layout da HUD (corner, posição, cores).
- Necessita GPU compatível, drivers CUDA e pipeline de build atualizado (`Build.ps1`).
- Para testes/agentes, utilizar as pastas físicas em `AgentsFiles-to-tester_folder_terminals/` ao configurar junctions.

## Uso recomendado
- Adequado para setups que desejam rodar apenas indicadores e ainda assim aproveitar a engine GPU.
- Ajustar `InpCycleCount`/`InpMaxCandidates` conforme o horizonte temporal do ativo; ciclos em excesso aumentam custo da GPU.
- Utilizar os botões para depuração (por exemplo, desativar ruído/ciclos e comparar wave vs. preço).
- Garantir presença do `ZigZag.mq5` homólogo ao lado do indicador quando estiver usando modos `Feed_ZigZag*`.
