# CMakeLists.txt (client_ipc)

## Propósito
- Define o target `GpuEngineClient.dll`, responsável por expor a API consumida pelos scripts MQL e ferramentas externas.

## Configuração
- Ajusta `BIN_DIR` para o diretório canonical (`GPU_CANONICAL_BIN`) respeitando caminhos relativos.
- Usa C++20 e cria biblioteca compartilhada com `src/Client.cpp`.
- Inclui diretórios de headers compartilhados (`Include/client_ipc`, `Include/ipc`, `Include/engine_core`).
- Define `GPU_ENGINE_BUILD` para ativar exports corretos no header.
- Especifica `OUTPUT_NAME` e diretórios de artefatos (runtime/library/archive) para todas as configurações de build, garantindo que o DLL seja depositado no diretório escolhido.

## Integração
- Este projeto é dependência para scripts PowerShell como `Build.ps1` e `GPUDevCLI.ps1` (pipelines de build).
- Deve ser invocado juntamente com os projetos `engine_core` e `service` para compor o conjunto completo de binários da WaveSpec GPU.
