# main.cpp (runtime)

## Visão geral
- Ponto de entrada do `GpuEngineService.exe` distribuído; apenas instancia `Service` e chama `Run()`.
- É mantido sincronizado com o arquivo equivalente em `Dev/src/service/src/`.
