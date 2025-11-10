# GpuEngineExports.h

## Propósito
- Declara as funções exportadas pelo `GpuEngine.dll`, fornecendo interface C compatível com consumidores como `GpuEngineClient.dll` e ferramentas externas.
- Define macro `GPU_EXPORT` para controlar `__declspec(dllexport/dllimport)` conforme o alvo e o define `GPU_ENGINE_BUILD`.

## Funções exportadas
- `GpuEngine_Init` / `GpuEngine_Shutdown`: inicializam/desligam o singleton retornado por `gpuengine::GetEngine()`.
- `GpuEngine_SubmitJob`, `GpuEngine_PollStatus`, `GpuEngine_FetchResult`: proxies diretos para métodos da classe `Engine`, operando sobre `gpuengine::JobDesc`/`ResultInfo`.
- `GpuEngine_GetStats`: devolve latência média/máxima calculada no núcleo.
- `GpuEngine_GetLastError`: copia string textual com a última falha.

## Integração
- Inclui `GpuEngineTypes.h` para compartilhar `gpuengine::ResultInfo` (estrutura também usada no lado MQL e no protocolo IPC).
- Implementação das funções encontra-se em `Dev/src/engine_core/src/exports.cpp`, que converte parâmetros C em chamadas aos métodos C++.
- Reutilizado tanto pela DLL (carregada em terminais/HUB) quanto pelo serviço Windows (`GpuEngineService.exe`), garantindo ABI consistente.
