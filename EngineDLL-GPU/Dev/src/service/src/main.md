# main.cpp

## Propósito
- Ponto de entrada de `GpuEngineService.exe`.
- Instancia a classe `Service` e delega execução ao método `Run()`.

## Integração
- Compilado junto com `Service.cpp` e `PipeServer.cpp`; depende do cabeçalho `Service.h`.
- Todo o comportamento do serviço está encapsulado em `Service::Run`, mantendo `main` minimalista para facilitar testes unitários/futuros.
