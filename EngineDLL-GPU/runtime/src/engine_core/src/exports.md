# exports.cpp (runtime)

## Visão geral
- Camada de exports C do `GpuEngine.dll` runtime, idêntica ao código construído em `Dev/src/engine_core/src/exports.cpp`.
- Converte parâmetros C em chamadas à classe `gpuengine::Engine`.

## Observação
- Manter sincronizado com a versão de desenvolvimento via watchdog; não editar diretamente na árvore runtime.
