# CudaProcessor.h

## Propósito
- Encapsula toda a lógica CUDA/cuFFT responsável por processar jobs enviados ao engine GPU.
- Provê alocação de buffers, criação de planos FFT e execução do pipeline GPU (pré-processamento, reconstrução, máscaras, ciclos).

## Estrutura interna
- Classe `gpuengine::CudaProcessor` com interface pública:
  - `Initialize(const Config&)`: seleciona dispositivo, aloca buffers em GPU, cria streams/eventos.
  - `Shutdown()`: libera buffers, planos e reseta estado.
  - `Process(JobRecord&)`: recebe job já validado e executa pipeline CUDA preenchendo os vetores `JobRecord`.
- Membros privados:
  - `PlanBundle`: cache de planos FFT (`forward`/`inverse`) indexado por `batch`.
  - Métodos auxiliares (`EnsureDeviceConfigured`, `EnsureBuffers`, `ReleaseBuffers`, `ReleasePlans`, `AcquirePlan`, `ProcessInternal`).
  - Ponteiros para buffers device (time/freq domain), máscara de preview e estruturas de ciclos.
  - `cudaStream_t` e eventos para medir latência.
  - `std::unordered_map<int, PlanBundle>` permitindo reuso de planos por tamanho de batch.

## Integração
- Utilizada exclusivamente pela classe `gpuengine::Engine` (`GpuEngineCore.h`/`.cpp`), que delega a ela o processamento pesado.
- Depende das estruturas definidas em `GpuEngineTypes.h` e `GpuEngineJob.h`.
- Espera que a configuração (`Config`) já esteja validada pelo engine (device, window, hop, batch).

## Requisitos
- Necessita CUDA Toolkit (inclui cabeçalhos `cuda_runtime.h`, `cufft.h`, `cuComplex.h`) e suporte a streams/eventos.
- Compilado como parte do projeto `GpuEngine.dll` (`Dev/src/engine_core`), respeitando `GPU_ENGINE_BUILD`.
