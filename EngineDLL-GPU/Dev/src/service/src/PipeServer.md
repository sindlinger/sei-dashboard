# PipeServer.cpp

## Propósito
- Implementa os métodos declarados em `PipeServer.h`, encapsulando operações de named pipe para o serviço GPU.

## Destaques
- `Create()`: cria pipe duplex (`PIPE_ACCESS_DUPLEX`) com buffers de 32 KB e 1 instância simultânea; registra erros via `std::fprintf`.
- `WaitForClient()`: aguarda conexão (`ConnectNamedPipe`) e trata o caso em que o cliente já está conectado (`ERROR_PIPE_CONNECTED`).
- `ReadExact`/`WriteExact`: leitura/escrita bloqueante até consumir o número de bytes solicitado; em falhas, imprime erro, fecha pipe e sinaliza `false`.
- `FlushFileBuffers` garante que a resposta seja enviada antes de reutilizar o pipe.
- Métodos `Disconnect()` e `Close()` limpam o handle, permitindo reiniciar o ciclo para novos clientes.

## Integração
- Usado por `Service::Run()` para construir o loop de atendimento; garante que cada comando do cliente seja transferido integralmente.
