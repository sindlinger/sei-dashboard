# GPU_Shared.mqh (runtime)

## Visão geral
- Replica o namespace `GPUShared` definido em `Dev/Include/GPU/GPU_Shared.mqh`.
- Fornece buffers compartilhados que os indicadores runtime leem após a publicação do EA Hub ou dos indicadores solo.

## Papel no runtime
- Mantido pelo watchdog; não editar manualmente — quaisquer adições de buffers devem ser feitas na árvore `Dev/`.
- Deve permanecer alinhado ao layout retornado por `GpuEngineClient.dll`/`GpuEngine.dll` para evitar inconsistências.
