# GPU_EnginePing.mq5

## Visão geral
- Expert Advisor mínimo usado para validar a instalação do `GpuEngineClient.dll`/`GpuEngineService.exe`.
- Realiza handshake, submete um job sintético e informa resultado no log, sem publicar buffers ou interagir com `GPU_Shared`.

## Organização interna
- **Imports**: mesma API do cliente GPU utilizada pelo Hub, incluindo `GpuEngineResultInfo`.
- **Inputs**: `InpGPU`, `InpWindow`, `InpHop`, `InpBatch`, `InpProfiling`, `InpUseGpuService`, `InpVerboseLog`.
- **Processo de inicialização** (`OnInit`):
  - Força `use_service=true` (serviço obrigatório nesta build, exceto em tester).
  - Ativa/desativa logging através de `GpuSetLogging`.
  - Chama `GpuClient_Open` e, em caso de erro, recupera detalhes com `GpuClient_GetLastError`.
  - Solicita o nome do backend (`GpuClient_GetBackendName` ou `GpuClient_IsServiceBackend`).
  - Cria um frame vazio (`ArrayInitialize`), envia `GpuClient_SubmitJob` de teste e aguarda `GpuClient_PollStatus`.
  - Reporta sucesso ou falha do ciclo de vida básico (submit/poll/fetch).
- **OnDeinit** restaura estado de logging original e chama `GpuClient_Close`.

## Integração com o GpuEngine
- Não interage com `GPU_Shared`; serve apenas para validar a API cliente <-> serviço.
- Testa códigos de retorno e logs para garantir que o serviço responde antes de usar o Hub.
- Os buffers usados (`g_gpuEmptyPreviewMask`, `g_gpuEmptyCyclePeriods`) fornecem placeholders válidos para o job sintético.

## Uso recomendado
- Executar sempre que houver dúvida sobre a instalação/links do serviço, especialmente após rodar `SetupAgentTesterLinks.ps1`.
- Útil em ambientes de teste (Strategy Tester) para verificar se o backend muda automaticamente para DLL local.
- Caso falhe, revisar se `Build.ps1` compilou `GpuEngineService.exe` e se os executáveis estão mapeados nos diretórios de agentes corretos.
