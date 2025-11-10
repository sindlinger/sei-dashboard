# GPU_Subwindows.mqh (runtime)

## Visão geral
- Mesma classe utilitária `CSubwindowController` usada no desenvolvimento para anexar/destacar indicadores GPU em sub-janelas.

## Papel no runtime
- Carregada pelo `GPU_EngineHub` runtime; garante que gráficos operacionais possam criar/fechar sub-janelas automaticamente.
- Alterações devem ser feitas no arquivo homônimo em `Dev/Include/GPU/` e propagadas pelo watchdog.
