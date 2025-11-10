# GPU_WaveViz.mq5

## Visão geral
- Indicador multi-plot que apresenta a wave reconstruída pela GPU, o ruído residual e até 12 ciclos harmônicos calculados pelo engine.
- Destina-se a quem utiliza o EA `GPU_EngineHub` como produtor: lê os buffers compartilhados em `GPU_Shared.mqh` e espelha a última janela calculada.

## Organização interna
- Declara 14 buffers (`g_bufWave`, `g_bufNoise` e `g_bufCycle1`…`g_bufCycle12`), todos tratados como séries invertidas (`ArraySetAsSeries`).
- `OnInit` define os buffers, inicializa as propriedades visuais e limpa os arrays.
- `ClearCycleBuffers` + `SetCycleValue` facilitam zerar e endereçar os ciclos dinamicamente.
- `OnCalculate`:
  - Valida `GPUShared::frame_count`, `frame_length` e `cycle_count`.
  - Determina quantos ciclos mostrar (`InpMaxCycles` limitado ao tamanho disponível).
  - Copia a amostra mais recente (`offset = (frame_count - 1) * frame_length`) para o índice zero, respeitando as flags `InpShowNoise`/`InpShowCycles`.
  - Ignora dados inconsistentes substituindo por `EMPTY_VALUE`, mantendo o gráfico limpo.

## Integração com o GpuEngine
- Usa `../../Include/GPU/GPU_Shared.mqh`, que expõe arrays populados pelo cliente MQL5 (`GpuEngineClient.dll`).
- Depende de `GPU_EngineHub.mq5` (ou indicador solo equivalente) para enfileirar trabalhos no engine e disponibilizar buffers de wave/cycles.
- Os nomes dos ciclos seguem a ordem retornada pela GPU; o indicador não reordena por potência/PLV.

## Requisitos e flags
- Inputs principais:
  - `InpShowNoise`: habilita gráfico do ruído reconstruído.
  - `InpShowCycles`: liga/desliga desenho dos ciclos.
  - `InpMaxCycles`: define limite superior de ciclos renderizados (<=12).
- Requer que `GPU_Shared` esteja sincronizado via watchdog (`WatchdogFiles_dev_to_runtime.py`) entre `Dev` e `runtime`.
- Não realiza chamadas diretas ao DLL; apenas leitura de memória compartilhada.

## Uso recomendado
- Carrgar após iniciar `GPU_EngineHub` para comparar wave limpa × preço e avaliar contribuição de cada ciclo.
- Ajustar `InpMaxCycles` quando o engine estiver configurado para decompor em menos componentes, evitando linhas vazias.
- Em terminais runtime, garantir que o link para `Dev/Indicators/GPU/GPU_WaveViz.mq5` esteja correto via `SetupRuntimeLinks.ps1`.
