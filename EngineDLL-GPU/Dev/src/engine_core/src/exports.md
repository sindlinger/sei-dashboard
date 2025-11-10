# exports.cpp

## Propósito
- Implementa as funções `GpuEngine_*` exportadas pela DLL, encaminhando chamadas para o singleton `gpuengine::Engine`.
- Aplica validações básicas nos parâmetros recebidos da API C antes de delegar ao núcleo C++.

## Fluxo
- `GpuEngine_Init`: monta `gpuengine::Config` com device/window/hop/batch/profiling e chama `Engine::Initialize`.
- `GpuEngine_SubmitJob`:
  - Preenche `gpuengine::JobDesc` com ponteiros fornecidos pelo cliente.
  - Normaliza parâmetros (clamp de thresholds, fallback para sigma/width, limites de iterações do Kalman).
  - Converte `kalman_preset` para enum `KalmanPreset` e define `mask.max_candidates`.
  - Invoca `Engine::SubmitJob` e, em caso de sucesso, devolve `handle.internal_id` em `out_handle`.
- `GpuEngine_PollStatus`: cria `JobHandle` com `internal_id` e consulta `Engine::PollStatus`.
- `GpuEngine_FetchResult`: passa todos os ponteiros de saída e recebe `ResultInfo`; copia `result_info` para `info` fornecido pelo chamador.
- `GpuEngine_GetStats`/`GpuEngine_GetLastError`: wrappers para introspecção e diagnóstico.

## Integração
- Compõe a camada de ABI estável usada pelo cliente DLL (`Client.cpp`) e pelo serviço.
- Garantir que qualquer ajuste nas estruturas (`JobDesc`, `ResultInfo`) seja refletido tanto aqui quanto no lado MQL/IPC.
