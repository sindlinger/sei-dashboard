# GPU_PhaseViz.mq5

## Visão geral
- Indicador em janela separada que exibe fase, amplitude, período estimado e demais métricas calculadas pela WaveSpec GPU.
- Consome exclusivamente os buffers publicados em `GPU_Shared.mqh`, que por sua vez são preenchidos pelo `GpuEngineClient.dll` via EAs como `GPU_EngineHub` ou indicadores “solo”.

## Organização interna
- Declara 12 buffers (`g_bufPhase`, `g_bufAmplitude`, `g_bufPeriod`, `g_bufEta`, `g_bufRecon`, `g_bufConfidence`, `g_bufAmpDelta`, `g_bufPhaseUnwrapped`, `g_bufKalman`, `g_bufTurn`, `g_bufCountdown`, `g_bufDirection`).
- `OnInit` registra cada buffer com `SetIndexBuffer`, força ordem inversa (`ArraySetAsSeries`) e define o nome curto “GPU PhaseViz”.
- `OnCalculate` valida `GPUShared::frame_count` e `frame_length`, verifica se todos os arrays compartilhados têm tamanho `frame_count * frame_length` e, só então, copia os valores da amostra mais recente para o índice zero dos buffers locais.
- Lacunas ou ausência de dados recebem `EMPTY_VALUE`, garantindo que o MetaTrader não trace linhas inválidas.

## Integração com o GpuEngine
- Este indicador **não** conversa diretamente com `GpuEngineClient.dll`; ele apenas lê os dados publicados pelo cliente GPU através de `../../Include/GPU/GPU_Shared.mqh`.
- Depende de algum produtor ativo (ex.: `Dev/Experts/GPU/GPU_EngineHub.mq5`, `GPU_PhaseViz_Solo.mq5` ou `GPU_WaveViz_Solo.mq5`) para alimentar os buffers compartilhados.
- Consulta `GPUShared::last_info` para recuperar metadados como ciclo dominante e confiança.

## Requisitos e flags
- Necessita que o cliente GPU esteja em execução e sincronizado com o `runtime/` por meio do watchdog para que `GPU_Shared.mqh` possua dados atualizados.
- Requer janela separada (`#property indicator_separate_window`) devido ao número de buffers.
- Não há parâmetros de entrada; a configuração é feita no produtor (EA ou indicador solo).

## Uso recomendado
- Anexar ao gráfico depois de iniciar o `GPU_EngineHub` (ou outro produtor) para visualizar fase + countdown em tempo real.
- Verificar se `GPU_Shared.mqh` está linkado para o mesmo diretório (`SetupRuntimeLinks.ps1`/`WatchdogFiles_dev_to_runtime.py`).
- Quando a GPU estiver inativa ou `frame_count`/`frame_length` forem zero, todos os plots serão silenciados por design.
