# OpenAdminPowerShell.ps1

Script utilitário para abrir rapidamente um Windows PowerShell elevado (RunAs) já posicionado na raiz do projeto WaveSpecGPU.

## Como usar

No WSL (ou em qualquer prompt Windows) execute:

```bash
cmd.exe /c "powershell -NoProfile -ExecutionPolicy Bypass -File C:\\Users\\pichau\\AppData\\Roaming\\MetaQuotes\\Terminal\\3CA1B4AB7DFED5C81B1C7F1007926D06\\MQL5\\WaveSpecGPU\\OpenAdminPowerShell.ps1"
```

1. Confirme o UAC.
2. Uma nova janela de PowerShell abrirá com privilégios de administrador em `C:\Users\pichau\AppData\Roaming\MetaQuotes\Terminal\3CA1B4AB7DFED5C81B1C7F1007926D06\MQL5\WaveSpecGPU`.

## Personalização

- **Alterar diretório inicial:** ajuste o argumento `-WorkingDirectory` dentro do `.ps1`.
- **Integrar a outras automações:** chame o `.ps1` antes de scripts que precisem parar/ iniciar serviços ou criar junctions (por exemplo, pipeline 9 do `GPUDevCLI`).

## Criando agentes tester (caso o script avise que faltam)

1. Abra o MetaTrader (MetaTrader 5 ou Dukascopy MetaTrader 5).
2. Vá em `Ferramentas > Opções > Agentes`.
3. Clique em **Adicionar** e informe o diretório do agente indicado na mensagem (ex.: `C:\Program Files\MetaTrader 5\Tester\Agent-0.0.0.0-2005`).
4. Repita para cada agente ausente.

Depois de adicionar, execute novamente `SetupAgentTesterLinks.ps1` (ou o pipeline 9) para recriar as junctions.
