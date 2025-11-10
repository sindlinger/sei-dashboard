# CMakeLists.txt (service)

## Propósito
- Configura o build do executável `GpuEngineService.exe`, responsável por hospedar o engine GPU via named pipe.

## Configuração
- Usa C++20 e herda `GPU_CANONICAL_BIN` para determinar onde depositar o executável.
- `add_executable(GpuEngineService src/main.cpp src/PipeServer.cpp src/Service.cpp)` reúne ponto de entrada e utilitários do serviço.
- Diretórios de include: árvore `Include/service`, `Include/ipc`, `Include/engine_core`.
- Linka contra `GpuEngine` (biblioteca produzida por `Dev/src/engine_core`) para reutilizar o núcleo CUDA.
- Define diretórios de saída (`RUNTIME/LIBRARY/ARCHIVE`) para todas as configurações de build, mantendo o executável junto com as DLLs.

## Integração
- `Build.ps1` invoca este target após gerar `GpuEngine.dll`, garantindo que o serviço encontre o engine na mesma pasta.
- Os scripts de implantação (`deploy_gpu_binaries.py`, `SetupAgentTesterLinks.ps1`) replicam o executável para runtime/agentes.
