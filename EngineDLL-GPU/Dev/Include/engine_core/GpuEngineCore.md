# GpuEngineCore.h

## Propósito
- Declara a classe `gpuengine::Engine`, núcleo multi-thread que gerencia fila de jobs, workers CUDA e estatísticas do pipeline.
- Expõe API C++ de alto nível utilizada pelas exports C (`GpuEngineExports.h`) e pelo serviço Windows.

## Organização
- Métodos públicos: `Initialize`, `Shutdown`, `SubmitJob`, `PollStatus`, `FetchResult`, `GetStats`, `GetLastError`.
- Estruturas auxiliares:
  - `m_workers`: threads que executam `WorkerLoop`, cada uma processando jobs com `CudaProcessor`.
  - `m_job_queue` + `m_jobs`: fila FIFO de IDs e mapa para `JobRecord`.
  - `m_queue_mutex`/`m_queue_cv`: sincronização entre produtores (Submit) e consumidores (workers).
  - Estatísticas (`m_total_ms`, `m_max_ms`, `m_completed_jobs`) protegidas por `m_stats_mutex`.
  - `m_last_error` guardado sob `m_error_mutex`.
  - `m_processor`: ponteiro único para `CudaProcessor`.
- Funções privadas: `WorkerLoop()` (consome queue, chama `m_processor->Process`), `ResetState()` (limpa estado entre inicializações).

## Integração
- Inclui `GpuEngineTypes.h` e `GpuEngineJob.h` para usar `Config`, `JobDesc`, `ResultInfo`, `JobRecord`.
- `GetEngine()` fornece singleton global utilizado pelas funções exportadas em `Dev/src/engine_core/src/exports.cpp`.
- Sincroniza com `GpuEngineClient`/serviço via IDs em `JobHandle` (espelhados no lado MQL).

## Requisitos
- Projetado para builds com `std::thread`, `std::condition_variable` e `std::atomic`.
- Antes de chamar `SubmitJob`, `Initialize` deve ter sucesso; caso contrário, retornos `STATUS_NOT_INITIALISED`.
- `WorkerLoop` assume que `CudaProcessor` já configurou device/streams; erros são capturados e expostos por `GetLastError`.
