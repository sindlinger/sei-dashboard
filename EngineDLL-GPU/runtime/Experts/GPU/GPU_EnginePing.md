# GPU_EnginePing.mq5 (runtime)

## Visão geral
- Cópia de `Dev/Experts/GPU/GPU_EnginePing.mq5`, usada para validar rapidamente a comunicação com `GpuEngineService.exe` nas estações runtime.

## Papel no runtime
- Executado em terminais destino para verificar se os links das DLLs/serviço estão corretos após deploy.
- Não publica buffers; somente loga resultado do handshake com o backend.

## Integração
- Requer os mesmos arquivos binários do hub e utiliza `GpuEngineClient.dll` instalado nos diretórios físicos de agentes.
