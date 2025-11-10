# CMakeLists.txt (engine_core)

## Propósito
- Configura a compilação do `GpuEngine.dll`, componente central escrito em C++/CUDA.

## Configuração de build
- Exige CMake ≥ 3.21, define C++20 e CUDA17, além de `POSITION_INDEPENDENT_CODE`.
- Localiza o CUDA Toolkit (`find_package(CUDAToolkit REQUIRED)`) e verifica a presença de `cudadevrt.lib` no diretório de binários (`GPU_CANONICAL_BIN`).
- Define arquitetura padrão `sm_86` (`CMAKE_CUDA_ARCHITECTURES "86"`), podendo ser ajustada conforme GPU alvo.
- Targets:
  - Biblioteca compartilhada composta por `src/GpuEngineCore.cpp`, `src/CudaProcessor.cu`, `src/exports.cpp`.
  - Includes: diretórios da engine (`Include/engine_core`) + headers do CUDA.
  - Links: `CUDA::cufft`, `CUDA::cudart`, `cudadevrt.lib` estático.
- Propriedades extras: separação de compilação, resolução de símbolos device, runtime híbrido e exportação de `compile_commands.json`.
- Replica diretórios de saída (`RUNTIME/LIBRARY/ARCHIVE`) para todas as configurações (Debug/Release/RelWithDebInfo/MinSizeRel).

## Integração
- Este target deve ser compilado antes do cliente e do serviço; os scripts PowerShell automatizam a sequência.
- O binário gerado é consumido tanto diretamente (indicadores solo, Strategy Tester) quanto pelo serviço Windows.
