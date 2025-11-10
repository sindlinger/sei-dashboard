# PipeServer.h

## Propósito
- Encapsula operações de servidor de named pipe no Windows para o serviço GPU.
- Responsável por criar, aceitar, ler e escrever mensagens entre `GpuEngineService.exe` e `GpuEngineClient.dll`.

## Estrutura
- Classe `PipeServer` com interface:
  - Construtor recebe nome do pipe (`std::wstring`).
  - `Create()`: chama `CreateNamedPipeW` com parâmetros apropriados.
  - `WaitForClient()`: bloqueia até que um cliente se conecte.
  - `Disconnect()` / `Close()`: encerram a sessão atual e liberam handle.
  - `ReadExact` / `WriteExact`: garantem transmissão de tamanho exato, repetindo chamadas a `ReadFile`/`WriteFile` até completar.
- Mantém `HANDLE m_pipe` e nome original para reuso em loops de atendimento.

## Integração
- Utilizada pela classe `Service` (`Service.h`/`Service.cpp`) para implementar o loop de atendimento a clientes.
- Opera somente em Windows; builds multiplataforma precisariam de implementação alternativa.
