# GPU_Shared.mqh

## Propósito
- Define namespace `GPUShared` contendo todos os buffers compartilhados entre produtores (EA Hub, indicadores solo) e consumidores (indicadores Wave/Phase, scripts de diagnóstico).
- Serve como contrato de dados no lado MQL5 para replicar a estrutura retornada por `GpuEngineClient.dll`.

## Estrutura interna
- Garante presença de `GpuEngineResultInfo` quando ainda não definido, alinhado ao header C++.
- Namespace `GPUShared` expõe:
  - Metadados (`last_update`, `frame_count`, `frame_length`, `cycle_count`, `dominant_*`).
  - Buffers principais (`wave`, `preview`, `noise`, `cycles`, `measurement`, `cycle_periods`).
  - Séries derivadas (fase, amplitude, período, frequência, ETA, countdown, recon, kalman, turn, confiança, amp_delta, direction, power, velocity).
  - Versões “_all” para dados por ciclo individual e vetores de métricas (`plv_cycles`, `snr_cycles`).
  - Estrutura `last_info` com snapshot completo do job mais recente.
- Funções utilitárias:
  - `EnsureSize(total, cycles_total, cycles_count)`: redimensiona todos os arrays conforme o job atual.
  - `Publish(...)`: copia buffers calculados pelo produtor para as variáveis globais e atualiza `last_update`.
  - `Clear()`: zera metadados quando não há dados válidos.

## Integração com o GpuEngine
- Consumido por EAs/indicadores que operam `GpuClient_FetchResult`; após obter os vetores do engine, copiam-nos para `GPUShared::Publish`.
- Indicadores (`GPU_WaveViz`, `GPU_PhaseViz`) somente leem esse namespace; nunca chamam o cliente GPU diretamente.
- Deve acompanhar a definição de `gpuengine::ResultInfo` no lado C++ para manter alinhamento de tamanho/layout.

## Requisitos e uso
- Arquivo incluído via `#include <GPU/GPU_Shared.mqh>` em todos os MQLs que precisam dos buffers.
- Precisa estar sincronizado entre `Dev/Include` e `runtime/Include` (scripts watchdog garantem).
- Ao adicionar novos buffers no C++ (ex.: `snr_cycles`), atualizar `EnsureSize` e `Publish` para evitar leituras fora do array.
