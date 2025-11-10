# GpuEngineClientApi.h (runtime)

## Visão geral
- Header sincronizado com `Dev/Include/client_ipc/GpuEngineClientApi.h`, declarando a API C exposta por `GpuEngineClient.dll`.

## Papel no runtime
- Consumido pelos builds runtime (MetaTrader) para importar a DLL corretamente.
- Deve permanecer idêntico ao arquivo de desenvolvimento; atualizações vêm do pipeline `Build.ps1` + watchdog.
