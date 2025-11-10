# GpuEngineClientApi.h

## Propósito
- Declara a API C (`extern "C"`) exportada por `GpuEngineClient.dll`, usada por scripts MQL5 para interagir com o serviço GPU via DLL.
- Serve como ponte entre o wrapper MQL (imports) e a implementação C++ (`Dev/src/client_ipc/src/Client.cpp`).

## Funções expostas
- `GpuClient_Open` / `GpuClient_Close`: inicializam/derrubam o cliente com parâmetros de hardware (GPU, janela, hop, batch, profiling, backend preferido, modo tester).
- `GpuClient_SubmitJob`: envia frames e metadados (máscara, ciclos, medições, presets Kalman). Retorna handle (`std::uint64_t`) que identifica o job.
- `GpuClient_PollStatus`: testa estado do job (em progresso, pronto, erro).
- `GpuClient_FetchResult`: copia para buffers fornecidos todos os outputs (wave, preview, cycles, métricas derivadas, PLV/SNR) e devolve `ResultInfo`.
- `GpuClient_GetStats`: agrega latência média/máxima.
- `GpuClient_GetLastError`: recupera mensagem textual da última falha.
- `GpuClient_GetBackendName` / `GpuClient_IsServiceBackend`: informam backend ativo (serviço Windows, DLL direta, tester).

## Integração
- Inclui `GpuEngineExports.h` para reutilizar o macro `GPU_EXPORT` e a struct `gpuengine::ResultInfo`, garantindo simetria com o lado engine.
- Consumido por `Client.cpp`, que implementa toda a lógica IPC e garante que mensagens obedecem ao protocolo definido em `Include/ipc/ServiceProtocol.h`.

## Uso
- Qualquer consumidor (MQL, ferramentas C++) deve incluir este header para linkagem com `GpuEngineClient`.
- As assinaturas espelham 1:1 as funções importadas nos arquivos `.mq5`, facilitando validação durante atualizações.
