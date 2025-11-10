# CudaProcessor.cu (runtime)

## Visão geral
- Fonte CUDA do engine runtime, espelho direto do arquivo em `Dev/src/engine_core/src/`.
- Contém kernels e lógica de processamento GPU utilizados pela DLL/serviço distribuídos.

## Observação
- Não editar diretamente; aplicar mudanças na árvore de desenvolvimento e sincronizar via watchdog para evitar divergência de binários.
