# GpuEngineCore.cpp (runtime)

## Visão geral
- Fonte C++ que implementa `gpuengine::Engine` no ambiente runtime, mantendo paridade com o arquivo em `Dev/src/engine_core/src/`.
- Inclui Kalman tracker, fila de jobs, workers, estatísticas e sanitização dos resultados GPU.

## Observação
- Alterações de lógica devem ser feitas na versão de desenvolvimento; esta cópia é atualizada automaticamente pelos scripts de sincronização.
