# Service.cpp

## Propósito
- Implementa o backend `GpuEngineService.exe`, que recebe comandos via named pipe, encaminha ao `GpuEngine.dll` e devolve resultados serializados.

## Componentes
- **Logging**: controla saída via `GPU_SERVICE_LOG`; escreve em `logs/gpu_service.log` e console com timestamps (`NowTimestamp`, `LogMsg`). Exibe banner com `BUILD_ID` e PID.
- **Sanitização**: `SanitizeSeries` normaliza vetores antes de enviá-los ao cliente, substituindo `NaN`/`EMPTY_VALUE`.
- **EngineState**: wrapper simples que inicializa/desliga o engine através das exports `GpuEngine_Init`/`GpuEngine_Shutdown`.
- **Protocolo**:
  - Usa `PipeServer` para aceitar clientes no pipe `\\.\pipe\WaveSpecGpuSvc`.
  - `ProcessClient` (no arquivo, não mostrado aqui integralmente) lê cabeçalhos `MessageHeader`, despacha comandos (`Init`, `SubmitJob`, `Poll`, `Fetch`, `Shutdown`), monta respostas (`StatusResponse`, `SubmitJobResponse`, `FetchResponseHeader`).
  - Mantém `m_jobs` com `JobMetadata` (frame_count/frame_length/cycle_count) para dimensionar buffers ao enviar `Fetch`.
  - Serializa vetores resultantes na sequência esperada pelo cliente (`wave`, `preview`, `cycles`, `noise`, séries derivadas, dados por ciclo, PLV/SNR).
- **main.cpp**: apenas instancia `Service` e chama `Run()`.

## Fluxo de execução
1. `Run()` cria diretório de logs, abre arquivo, imprime banner.
2. Cria `PipeServer`, aguarda cliente (`WaitForClient`) e processa comandos até `Shutdown`.
3. Em `SubmitJob`, registra metadados e repassa ponteiros para `GpuEngine_SubmitJob`.
4. Em `Fetch`, lê resultado do engine, sanitiza séries e escreve payload completo para o cliente.
5. Em caso de erro, envia status negativo (`gpu_service::Status`) e reinicia pipe.

## Integração
- Trabalha em conjunto com `Client.cpp`; qualquer mudança de protocolo deve ser aplicada em ambos.
- Executável é registrado e distribuído pelos scripts PowerShell (`SetupAgentTesterLinks.ps1`, `Build.ps1`).
