# Client.cpp

## Propósito
- Implementa a DLL `GpuEngineClient` usada pelos consumidores (MQL, scripts) para falar com `GpuEngineService.exe` via named pipes.
- Expõe todas as funções declaradas em `GpuEngineClientApi.h`.

## Fluxo geral
- Estrutura interna `PipeClient` (singleton `g_client`) gerencia conexão com `\\.\pipe\WaveSpecGpuSvc`, garantindo envio/recebimento confiável (`WriteExact`/`ReadExact`).
- Cada chamada pública serializa requests e lê respostas conforme `gpu_service::MessageHeader` definido em `ServiceProtocol.h`.
- Mantém locks com `std::mutex g_mutex` para evitar que múltiplas threads usem o pipe simultaneamente e preserva a última mensagem de erro em `g_last_error`.

## Funções principais
- `GpuClient_Open`: envia comando `Init`, registrando device/window/hop/batch; guarda modo serviço/tester para chamadas subsequentes.
- `GpuClient_SubmitJob`:
  - Limpa dados inválidos com `SanitizeSeries`.
  - Monta `gpu_service::SubmitJobRequest` e buffers com frames, máscara, ciclos e medições.
  - Serializa tudo para um blob contínuo usando helpers (`AppendVector`, `AppendArray`) antes de escrever no pipe.
  - Retorna handle recebido no `SubmitJobResponse`.
- `GpuClient_PollStatus`: emite `Poll` e retorna status do job (`STATUS_IN_PROGRESS`, `STATUS_READY` etc.).
- `GpuClient_FetchResult`: lê `FetchResponseHeader` seguido dos vetores (wave, preview, cycles, métricas, PLV/SNR), validando tamanhos e aplicando sanitização.
- `GpuClient_GetStats`, `GetLastError`, `GetBackendName`, `IsServiceBackend`: comandos utilitários para estadísticas e introspecção do backend.
- Em qualquer erro de transporte ou protocolo, armazena mensagem em `g_last_error` e encerra a conexão para forçar reconexão na próxima chamada.

## Integração
- Utiliza `gpuengine::ResultInfo` diretamente, permitindo que MQL leia os mesmos campos sem conversão extra.
- Fica posicionado no mesmo diretório de saída configurado pelo `CMakeLists.txt` correspondente.
- É invocado pelo EA Hub e indicadores solo via `import` MQL.
