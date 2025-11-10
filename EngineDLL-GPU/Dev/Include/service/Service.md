# Service.h

## Propósito
- Declara a classe `Service`, que implementa o backend Windows (`GpuEngineService.exe`) responsável por aceitar conexões de clientes via named pipe.
- Faz a ponte entre requests serializados (`ServiceProtocol.h`) e chamadas à API do engine (`GpuEngineExports.h`).

## Organização
- `Run()`: ponto de entrada; cria `PipeServer`, entra em loop aceitando clientes e processa comandos até receber `Shutdown`.
- Estrutura interna `JobMetadata`: guarda `frame_count`, `frame_length` e `cycle_count` por handle para dimensionar respostas `Fetch`.
- Métodos privados:
  - `ProcessClient(PipeServer&)`: loop principal de leitura/roteamento de comandos.
  - `SendStatus(...)`: utilitário para enviar respostas simples com `gpu_service::Status`.
- `m_jobs`: `unordered_map` que rastreia jobs ativos por handle, permitindo recuperar tamanhos durante o fetch.

## Integração
- Usa `PipeServer` para I/O síncrono; converte requests em chamadas aos exports `GpuEngine_*`.
- Compartilha `gpu_service::Command`/`Status` com o cliente C++ e, indiretamente, com os scripts MQL.
