# OpenAdminPowerShell.ps1

Script utilitário para abrir uma janela do Windows PowerShell elevada (RunAs) já posicionada na raiz do projeto WaveSpecGPU.

## Uso

No WSL ou em qualquer prompt, execute:

```bash
cmd.exe /c "powershell -NoProfile -ExecutionPolicy Bypass -File C:\\Users\\pichau\\AppData\\Roaming\\MetaQuotes\\Terminal\\3CA1B4AB7DFED5C81B1C7F1007926D06\\MQL5\\WaveSpecGPU\\OpenAdminPowerShell.ps1"
```

Após confirmar o UAC, a nova janela abrirá em `C:\Users\pichau\AppData\Roaming\MetaQuotes\Terminal\3CA1B4AB7DFED5C81B1C7F1007926D06\MQL5\WaveSpecGPU` com privilégios de administrador.

## Ajustes

- Alterar o diretório padrão: edite o argumento `-WorkingDirectory` no `.ps1`.
- Reutilizar em outros scripts: basta chamar o `.ps1` sempre que precisar subir um PowerShell elevated antes de executar ações como o pipeline 9 do CLI ou comandos que precisem encerrar serviços.

