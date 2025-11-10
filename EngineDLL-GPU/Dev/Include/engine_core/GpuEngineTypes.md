# GpuEngineTypes.h

## Propósito
- Reúne tipos fundamentais para o engine GPU: códigos de status, configurações, parâmetros de máscara/ciclo/Kalman, descrição de jobs e resultados.
- Compartilhado entre o core C++, cliente DLL e wrappers MQL para manter compatibilidade de estruturas.

## Conteúdo
- `enum StatusCode`: lista retornos possíveis (`STATUS_OK`, `STATUS_READY`, `STATUS_IN_PROGRESS`, `STATUS_QUEUE_FULL`, etc.).
- `struct Config`: parâmetros de inicialização (GPU, window, hop, batch, limite de ciclos, streams, profiling).
- `struct MaskParams`: controla gaussian mask usada durante pré-processamento (sigma, threshold, faixa de períodos, número de candidatos).
- `struct CycleParams`: descreve períodos selecionados manualmente (ponteiro, quantidade, largura relativa).
- `enum class KalmanPreset` + `struct KalmanParams`: configuram filtro de fase (process/measurement noise, iterações, thresholds).
- `struct JobDesc`: pacotes enviados ao engine (pointers para frames, mask, measurement, contadores, flags, upscale, presets).
- `struct ResultInfo`: metadados produzidos após processamento (dominant cycle, PLV, confiança, linha reconstruída, latência, status).

## Integração
- Incluído por quase todo o núcleo (`CudaProcessor`, `GpuEngineCore`, `JobRecord`, exports) e referenciado no protocolo IPC (`ServiceProtocol.h`).
- Estruturas espelhadas nas importações MQL (`GpuEngineResultInfo`) para garantir alinhamento binário.
