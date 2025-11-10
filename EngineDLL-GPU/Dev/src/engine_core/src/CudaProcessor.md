# CudaProcessor.cu

## Propósito
- Implementa o pipeline CUDA/cuFFT responsável por transformar frames de preço em wave reconstruída, ciclos harmônicos e métricas derivadas.
- É instanciado pela classe `gpuengine::CudaProcessor` declarada em `CudaProcessor.h`.

## Componentes principais
- **Infraestrutura de debug**: helpers `DebugEnabledCuda`, `DebugLogCuda`, `LogAnomalyCuda` permitem ativar logs via `GPU_ENGINE_DEBUG`.
- **Sanitização**: função `SanitizeSeries` substitui valores não finitos usando fallback ou último sample válido, registrando ocorrências.
- **Kernels CUDA** (exemplos):
  - `BuildBandpassMaskKernel`: calcula máscara gaussiana na frequência (limites min/max, threshold, softness).
  - `ApplyMaskKernel`, `ComputeCycleMagnitudeKernel`, `AccumulateCyclesKernel`: filtragem espectral e reconstrução das componentes.
  - `ComputeEnvelopeKernel`, `ComputePhaseKernel`, `ComputeCountdownKernel`, `ComputeVelocityKernel`: derivam amplitude, fase, ETA, velocidade etc.
  - Funções auxiliares para normalização (`NormalizeSeriesKernel`), clamps, cópia e reconstrução.
- **Gerenciamento de planos**: `AcquirePlan` busca/gera `cufftHandle` (forward/inverse) por batch, armazenando em `PlanBundle`.
- **Buffers device**: aloca e mantém ponteiros para time-domain (entrada, original, filtrado, ruído, ciclos), frequency-domain e máscaras/ciclos (`m_d_*`).
- **ProcessInternal(JobRecord&, PlanBundle&)**:
  1. Copia frames para buffers device.
  2. Executa FFT forward, aplica máscaras gaussianas/multiciclo.
  3. Calcula espectro selecionado, reconstrói wave filtrada/ruído/ciclos.
  4. Executa IFFT, extrai métricas (amplitude, fase unwrap, power, velocity, countdown, turn).
  5. Copia resultados de volta para vetores host (`job.wave`, `job.phase`, `job.cycles`, etc.).
  6. Atualiza `job.result` com metadados calculados (dominant cycle, tempo de execução).
- **Tratamento de erros**: macros `CUDA_CHECK`, `CUFFT_CHECK` retornam `STATUS_ERROR` imediatamente quando chamadas falham.

## Integração com o engine
- `Engine::WorkerLoop` invoca `Process(job)`; em caso de sucesso, `job.status` muda para `STATUS_READY`.
- `JobRecord` recebe os vetores populados e posteriormente são transferidos para `GPU_Shared` pelo Hub.
- Requer driver CUDA compatível, `cudadevrt.lib` e bibliotecas `cufft`/`cudart`, configurados no `CMakeLists` correspondente.
