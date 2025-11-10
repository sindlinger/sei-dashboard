# GPU_EngineHub.mq5

## Visão geral
- Expert Advisor que coordena o envio de jobs para o `GpuEngineClient.dll`, faz polling das respostas e publica todos os buffers em `Include/GPU/GPU_Shared.mqh`.
- Atua como “hub” central: coleta candles/zigzag, agrega lotes (`InpBatchSize`) e alimenta simultaneamente indicadores (`GPU_WaveViz`, `GPU_PhaseViz`) e HUDs.

## Organização interna
- **Imports**: carrega o conjunto completo de funções do cliente GPU mais `GpuEngineResultInfo`.
- **Buffers internos**: mantém arrays para wave, preview, cycles, fases, métricas auxiliares e séries ZigZag (todos tratados como séries invertidas).
- **Engine wrapper**: classe `g_engine` encapsula abertura (`Initialize`), submissão (`SubmitJob`), pooling (`PollStatus`), coleta (`FetchResult`) e encerramento (`Shutdown`).
- **Eventos principais**:
  - `OnInit`: escolhe backend (serviço, DLL direta ou tester), abre ZigZag via `iCustom`, registra timer (`EventSetMillisecondTimer`), coleta períodos iniciais (`CollectCyclePeriods`) e liga HUDs/indicadores automáticos conforme inputs.
  - `OnTick`: injeta candles recentes em `SubmitPendingBatches()` e tenta consumir resultados prontos (`PollCompletedJobs()`).
  - `OnTimer`: executa watchdogs de latência, atualiza HUD textual, e dispara reenvio de jobs se necessário.
  - `OnChartEvent`: trata interações de botões/atalhos (`g_hotkeys`) para anexar/remover indicadores Wave/Phase.
- **Publicação**: chama `GPUShared::Publish` com os arrays normalizados, atualizando `GPUShared::last_info` e registrando timestamp.

## Integração com o GpuEngine
- Usa `GpuClient_Open/SubmitJob/PollStatus/FetchResult` para operar jobs assíncronos.
- Estabiliza dados antes de publicar (`GpuSanitizeSeries`, `GpuSanitizeSeriesWithFallback`) e garante redimensionamento correto (`GpuEnsureCapacity`).
- Atualiza indicadores anexados via `CSubwindowController` (`GPU_Subwindows.mqh`) e injeta handles para `GPU_WaveViz.mq5`/`GPU_PhaseViz.mq5`.
- Preenche logs com backend ativo, latência média/máxima e erros devolvidos por `GpuClient_GetLastError`.

## Inputs e requisitos
- Principais entradas: dispositivo (`InpGPUDevice`), janela FFT (`InpFFTWindow`), hop (`InpHop`), batch (`InpBatchSize`), flags de serviço (`InpUseGpuService`), controle de hotkeys, parâmetros ZigZag e opções de HUD.
- Necessita que `GpuEngineClient.dll` (ou serviço Windows `GpuEngineService.exe`) esteja compilado pelo pipeline `Dev/src` e disponível na árvore `runtime/`.
- Para agentes/tester, respeitar o aviso do repositório: os binários residem em `AgentsFiles-to-tester_folder_terminals/` e não em `%APPDATA%`.

## Uso recomendado
- Rodar `GPU_EngineHub` em um gráfico mestre para alimentar indicadores em múltiplos charts.
- Ajustar `InpTimerPeriodMs` conforme a granularidade desejada; valores muito baixos podem saturar o serviço.
- Monitorar o log: ao detectar `STATUS_QUEUE_FULL` ou falhas de ZigZag, revisar a configuração de lotes/candles.
