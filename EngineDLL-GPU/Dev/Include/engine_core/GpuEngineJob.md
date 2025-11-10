# GpuEngineJob.h

## Propósito
- Define estruturas `JobHandle` e `JobRecord` usadas internamente pelo engine para rastrear jobs, buffers intermediários e resultados.
- Serve como contrato entre `GpuEngineCore` e `CudaProcessor`.

## Componentes
- `JobHandle`: identifica um job por `internal_id` (gerado pelo engine) e `user_tag` (propagado pelo consumidor).
- `JobRecord`: contém:
  - Cópias do `JobDesc` (`desc`) e buffers host (`input_copy`, `preview_mask`, `cycle_periods`).
  - Vários vetores para resultados (wave, preview, noise, cycles, fase, amplitude, período, frequência, velocity, power, countdown, recon, kalman, turn, confidence, amp_delta).
  - Versões “_all” para dados por ciclo, além de `plv_cycle`, `snr_cycle`.
  - Estrutura `ResultInfo result`.
  - Status (`std::atomic<int>`) com valores de `StatusCode`.
  - `submit_time` para cálculo de latência.

## Integração
- Preenchido pelo método `Engine::SubmitJob`, que realiza cópia de entradas e marca status `STATUS_IN_PROGRESS`.
- Processado por `CudaProcessor::Process`, que grava os vetores de saída e atualiza `result`.
- Consumido por `Engine::FetchResult`, que move os dados para buffers do chamador e atualiza estatísticas.
