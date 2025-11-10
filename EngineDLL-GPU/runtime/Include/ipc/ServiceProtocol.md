# ServiceProtocol.h (runtime)

## Visão geral
- Protocolo IPC utilizado por `GpuEngineClient.dll` e `GpuEngineService.exe` no ambiente runtime, preservando exatamente a mesma estrutura do arquivo em `Dev/Include/ipc/`.

## Papel no runtime
- Não deve ser editado manualmente; alterações de versão devem partir da árvore de desenvolvimento e ser replicadas pelos scripts de sincronização.
