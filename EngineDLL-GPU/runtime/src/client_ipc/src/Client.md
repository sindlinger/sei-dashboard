# Client.cpp (runtime)

## Visão geral
- Implementação do `GpuEngineClient.dll` distribuído para produção; cópia idêntica ao arquivo em `Dev/src/client_ipc/src/`.

## Papel no runtime
- Fornece o código C++ que será compilado no pipeline de publicação; usado para depuração quando a build ocorre diretamente na árvore runtime.
- Quaisquer correções devem ser feitas na versão de desenvolvimento e replicadas via watchdog.
