# ServiceProtocol.h

## Propósito
- Define o protocolo binário utilizado entre `GpuEngineClient.dll` e `GpuEngineService.exe` via named pipe `\\.\pipe\WaveSpecGpuSvc`.
- Especifica cabeçalhos, comandos, status codes e payloads para serializar chamadas do engine.

## Componentes principais
- Constantes `MESSAGE_MAGIC` (`'WGPU'`) e `PROTOCOL_VERSION` para validar mensagens.
- Enum `gpu_service::Command`: `Ping`, `Init`, `SubmitJob`, `Poll`, `Fetch`, `Shutdown`.
- Enum `gpu_service::Status`: códigos de erro/sucesso para cada chamada (ex.: `InitFailed`, `SubmitFailed`, `DecodeError`).
- Estruturas de mensagens:
  - `MessageHeader`: prefixo comum com magic, versão, comando e tamanho do payload.
  - `StatusResponse`: usado por comandos simples (ping, shutdown).
  - `InitRequest`: configura GPU, janela, hop, batch, profiling.
  - `SubmitJobRequest`/`SubmitJobResponse`: descrevem job, parâmetros de máscara, ciclos, Kalman e tamanhos dos arrays anexos.
  - `PollRequest`/`PollResponse`: acompanham progresso via handle.
  - `FetchRequest` + `FetchResponseHeader`: retornam `gpuengine::ResultInfo`, contagens e tamanhos dos vetores que seguem no stream.

## Integração
- Incluído por `Client.cpp` (lado cliente) e pelos serviços (`Service.cpp`/`main.cpp`), garantindo leitura/escrita consistente.
- Reaproveita `gpuengine::ResultInfo` de `GpuEngineTypes.h` para alinhar a estrutura transmitida.
- Atualizações desse protocolo exigem versionamento e compatibilização em ambos os lados antes de distribuir.
