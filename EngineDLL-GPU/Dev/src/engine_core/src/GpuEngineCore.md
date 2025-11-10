# GpuEngineCore.cpp

## Propósito
- Implementa a classe `gpuengine::Engine` e lógica auxiliar (Kalman tracker, distribuição de ciclos, workers) descritas em `GpuEngineCore.h`.
- Atua como orquestrador entre jobs recebidos, `CudaProcessor` e métricas derivadas.

## Destaques da implementação
- **Debug/Log**: helpers `DebugEnabled`, `DebugLog`, `LogAnomalyCore` escrevem em `gpu_debug.log` quando `GPU_ENGINE_DEBUG` está definido.
- **Sanitização**: `SanitizeSeries` substitui valores não finitos/`EMPTY_VALUE` antes de publicar resultados.
- **Kalman tracker** (`RunKalmanTracker`):
  - Inicializa vetores (fase, amplitude, período, frequência, countdown, velocity, confidence).
  - Usa parâmetros `job.desc.kalman` para filtrar fase dominante, calcular métricas de linha e detectar pulsos de turn.
  - Preenche arrays “_all” e estatísticas (`dominant_plv`, `dominant_confidence`).
- **Distribuição de ciclos**: funções auxiliares determinam ciclo dominante, ajustam PLV/SNR, normalizam amplitude e recon constroem a wave final.
- **WorkerLoop**:
  1. Extrai IDs de `m_job_queue`, recupera `JobRecord`.
  2. Invoca `m_processor->Process(job)` (CUDA) e, em seguida, `RunKalmanTracker(job)`.
  3. Atualiza `job.status`, `job.result` e estatísticas globais (`m_total_ms`, `m_max_ms`, `m_completed_jobs`).
  4. Em caso de exceção, registra mensagem em `m_last_error` e marca job como `STATUS_ERROR`.
- **Submit/Poll/Fetch**:
  - `SubmitJob` copia descritores/ciclos para o `JobRecord`, gera ID incremental (`m_next_id`), enfileira e notifica workers.
  - `PollStatus` e `FetchResult` sincronizam via `m_jobs`, removendo registros quando concluídos e preenchendo buffers de saída do chamador.
  - `FetchResult` também propaga `ResultInfo` e remove o job do mapa de ativos.
- **Stats/Error**: `GetStats` e `GetLastError` fornecem diagnósticos para o cliente.

## Integração
- Usado tanto pelo DLL (`exports.cpp`) quanto pelo serviço Windows (via `GpuEngineExports`).
- Requer instância de `CudaProcessor` inicializada em `Initialize`; falhas são propagadas via `STATUS_INVALID_CONFIG`/`STATUS_ERROR`.
