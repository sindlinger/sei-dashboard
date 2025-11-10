[CmdletBinding()]
param(
    [string[]]$Run
)

$scriptRoot = $PSScriptRoot

$optionDetails = @{
    "1" = @"
Pipeline completo:
  1. Build.ps1 recompila (CMake/MSBuild) e garante dependências CUDA em Dev/bin.
  2. WatchdogFiles_dev_to_runtime.py --apply --once espelha Dev -> runtime (Indicators/Experts/Include/Scripts/bin).
  3. SetupRuntimeLinks.ps1 recria as junções das instâncias MetaTrader apontando para Dev/ e Dev/bin.
  4. WatchdogLinks_runtime_m5folders.py --fix valida/ajusta os links após a recriação.
  5. Doctor (--auto) roda comparação Dev ↔ runtime e audita links_config.json.
  6. Reinicia runtime/bin\GpuEngineService.exe em modo usuário.
"@
    "2" = @"
Build (usar cache atual):
  - Executa Build.ps1 reaproveitando a pasta build_vs já configurada.
  - Ideal para rebuild rápido quando a configuração não mudou.
"@
    "3" = @"
Build (limpo):
  - Executa Build.ps1 -Clean (remove build_vs, reconfigura CMake e recompila tudo).
"@
    "4" = @"
Watchdog Dev -> runtime:
  - WatchdogFiles_dev_to_runtime.py --apply --once.
  - Copia Dev/bin -> runtime/bin e sincroniza Indicators, Experts, Include, Scripts.
"@
    "5" = @"
SetupAgentTesterLinks.ps1:
  - Recria junções dos agentes em Program Files\...\Tester\Agent-xxxx.
  - Requer abrir PowerShell como administrador.
"@
    "6" = @"
WatchdogLinks_runtime_m5folders.py --fix:
  - Ajusta junções nas instâncias MetaTrader (Include/Indicators/Experts/Scripts/Libraries -> Dev/ e Dev/bin).
"@
    "8" = @"
Reiniciar GpuEngineService.exe (modo usuário):
  - Stop-Process GpuEngineService; Start-Process runtime/bin\GpuEngineService.exe (janela oculta).
"@
    "9" = @"
Opção 1 + SetupAgentTesterLinks.ps1:
  - Executa o pipeline completo (Build -> Sync -> Links -> Doctor -> Serviço) e, em seguida, atualiza os agentes tester.
"@
    "10" = @"
Doctor (Dev/runtime + links):
  - Compara Dev/bin ↔ runtime/bin e pastas MQL (com opção de copiar/mover para Lixeira).
  - Valida cada entrada de links_config.json substituindo <GUID>.
"@
    "11" = @"
Links -> Dev (padrão de desenvolvimento):
  - Recria junções das instâncias MetaTrader apontando para Dev/ e Dev/bin.
"@
    "12" = @"
Links -> runtime (modo testes):
  - Reaponta junções para runtime/, útil quando o tester bloqueia DLLs do Dev/.
"@
    "13" = @"
Links -> caminho customizado:
  - Solicita um diretório base e recria as junções apontando para ele (usa subpastas de Dev/ como modelo).
"@
}

function Show-OptionDetails {
    param([string]$Number)
    if($optionDetails.ContainsKey($Number)) {
        Write-Host ""
        Write-Host "[Detalhes opção $Number]"
        Write-Host $optionDetails[$Number]
        return $true
    }
    Write-Warning "[CLI] Não há detalhes cadastrados para a opção $Number."
    return $false
}

function Process-DetailRequest {
    param([string]$InputValue)

    if([string]::IsNullOrWhiteSpace($InputValue)) {
        return $false
    }

    $trimmed = $InputValue.Trim()
    $number = $null
    if($trimmed -match '^\?(\d+)$') {
        $number = $Matches[1]
    }
    elseif($trimmed -match '^(\d+)\?$') {
        $number = $Matches[1]
    }
    elseif($trimmed -match '^info\s+(\d+)$') {
        $number = $Matches[1]
    }

    if($number) {
        Show-OptionDetails -Number $number | Out-Null
        return $true
    }
    return $false
}

function Execute-Option {
    param(
        [string]$Choice,
        [string]$CustomArgOverride = $null
    )

    $customArg = $null
    if($CustomArgOverride) {
        $customArg = $CustomArgOverride
    } elseif($Choice -match '^(\d+)[=:](.+)$') {
        $Choice = $Matches[1]
        $customArg = $Matches[2]
    }

    switch($Choice) {
        "1" {
            try { Invoke-PipelineService }
            catch { Write-Warning $_ }
            return $true
        }
        "2" {
            Invoke-Build
            return $true
        }
        "3" {
            Invoke-BuildClean
            return $true
        }
        "4" {
            Invoke-WatchdogSync
            return $true
        }
        "5" {
            Invoke-AgentLinks
            return $true
        }
        "6" {
            Invoke-FixLinks
            return $true
        }
        "8" {
            try { Invoke-StartService }
            catch { Write-Warning $_ }
            return $true
        }
        "9" {
            try { Invoke-PipelineService; Invoke-AgentLinks }
            catch { Write-Warning $_ }
            return $true
        }
        "10" {
            try { Invoke-DoctorDetailed -Auto:$script:CliAutoMode }
            catch { Write-Warning $_ }
            return $true
        }
        "11" {
            try { Invoke-SetupRuntimeLinks -Mode "Dev" }
            catch { Write-Warning $_ }
            return $true
        }
        "12" {
            try { Invoke-SetupRuntimeLinks -Mode "Runtime" }
            catch { Write-Warning $_ }
            return $true
        }
        "13" {
            $customPath = $customArg
            if(-not $customPath) {
                $customPath = Read-Host "[Links] Informe o diretório base (ex.: C\\Algum\\diretorio)"
            }
            if([string]::IsNullOrWhiteSpace($customPath)) {
                Write-Warning "[Links] Caminho customizado vazio. Nenhuma ação executada."
                return $true
            }
            try { Invoke-SetupRuntimeLinks -Mode "Custom" -CustomRoot $customPath }
            catch { Write-Warning $_ }
            return $true
        }
        "14" {
            Write-Host "[CLI] Encerrando."
            return $false
        }
        default {
            Write-Host "[CLI] Opcao invalida."
            return $true
        }
    }
}

$script:CliAutoMode = $false
$script:PythonExtraArgs = @()

function Resolve-Python {
    $script:PythonExtraArgs = @()

    $venvPython = Join-Path $scriptRoot "winvenv\Scripts\python.exe"
    if(Test-Path $venvPython) {
        return $venvPython
    }

    foreach($candidate in @("python", "python3")) {
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if($cmd) { return $cmd.Path }
    }

    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
    if($pyLauncher) {
        $script:PythonExtraArgs = @("-3")
        return $pyLauncher.Path
    }

    throw "Python nao encontrado no PATH."
}

function Invoke-Build {
    Write-Host ""; Write-Host "[Build] fazendo build incremental..."
    & (Join-Path $scriptRoot "Build.ps1")
}

function Invoke-BuildClean {
    Write-Host ""; Write-Host "[Build] fazendo build limpo..."
    & (Join-Path $scriptRoot "Build.ps1") -Clean
}

function Invoke-WatchdogSync {
    Write-Host ""; Write-Host "[Watchdog] sincronizando Dev -> runtime (--apply --once)..."
    $python = Resolve-Python
    $scriptPath = Join-Path $scriptRoot "watchdogs/WatchdogFiles_dev_to_runtime.py"
    $args = @()
    if($script:PythonExtraArgs) { $args += $script:PythonExtraArgs }
    $args += $scriptPath
    $args += @("--apply", "--once")
    & $python @args
}

function Invoke-SetupRuntimeLinks {
    param(
        [string]$Mode = "Dev",
        [string]$CustomRoot = $null
    )

    Write-Host ""; Write-Host ("[Links] configurando instancias (SetupRuntimeLinks.ps1 | modo {0})..." -f $Mode)

    $params = @{}
    if($Mode) {
        $params["SourceMode"] = $Mode
    }
    if($Mode -eq "Custom") {
        if([string]::IsNullOrWhiteSpace($CustomRoot)) {
            throw "CustomRoot obrigatorio quando modo=Custom."
        }
        $params["CustomRoot"] = $CustomRoot
    }

    foreach($key in $params.Keys) {
        Write-Verbose ("[Links] param {0} = '{1}'" -f $key, $params[$key])
    }
    & (Join-Path $scriptRoot "SetupRuntimeLinks.ps1") @params
    if($LASTEXITCODE -ne 0) {
        throw "SetupRuntimeLinks.ps1 falhou (codigo $LASTEXITCODE)"
    }
}

function Invoke-AgentLinks {
    Write-Host ""; Write-Host "[Agentes] atualizando slots e juncoes..."
    & (Join-Path $scriptRoot "SetupAgentTesterLinks.ps1")
}

function Invoke-FixLinks {
    Write-Host ""; Write-Host "[Instancias] corrigindo links das instancias (WatchdogLinks --fix)..."
    $python = Resolve-Python
    $scriptPath = Join-Path $scriptRoot "watchdogs/WatchdogLinks_runtime_m5folders.py"
    $args = @()
    if($script:PythonExtraArgs) { $args += $script:PythonExtraArgs }
    $args += $scriptPath
    $args += "--fix"
    & $python @args
}

function Invoke-Doctor {
    Write-Host ""; Write-Host "[Diagnostico] CheckLinks.ps1 em runtime/..."
    & (Join-Path $scriptRoot "CheckLinks.ps1") (Join-Path $scriptRoot "runtime") -Recurse -Summary
}

function Stop-GpuServiceIfRunning {
    $procs = Get-Process -Name "GpuEngineService" -ErrorAction SilentlyContinue
    if(-not $procs) { return }
    foreach($proc in $procs) {
        try {
            Write-Host "[Servico] Encerrando PID $($proc.Id)..."
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
        }
        catch {
            Write-Warning "[Servico] Falha ao encerrar PID $($proc.Id): $_"
            try {
                Write-Host "[Servico] Tentando taskkill /IM GpuEngineService.exe /F..."
                cmd.exe /c "taskkill /IM GpuEngineService.exe /F" | Out-Null
            }
            catch {
                Write-Warning "[Servico] taskkill também falhou: $_"
            }
        }
    }
    Start-Sleep -Seconds 1

    $remaining = Get-Process -Name "GpuEngineService" -ErrorAction SilentlyContinue
    if($remaining) {
        throw "Servico GpuEngineService.exe ainda em execucao (execute o CLI como administrador ou use a opcao 12 para apontar para runtime/)."
    }
}

function Invoke-StartService {
    Write-Host ""; Write-Host "[Servico] iniciando GpuEngineService.exe (modo usuario)..."
    $exeDir  = Join-Path $scriptRoot "runtime/bin"
    $exePath = Join-Path $exeDir  "GpuEngineService.exe"

    if(-not (Test-Path $exePath)) {
        throw "[Servico] Arquivo não encontrado: $exePath"
    }

    Stop-GpuServiceIfRunning

    try {
        $process = Start-Process -FilePath $exePath `
                                 -WorkingDirectory $exeDir `
                                 -WindowStyle Hidden `
                                 -PassThru
        if(-not $process) {
            throw "Processo não retornou handle."
        }
        Write-Host "[Servico] PID $($process.Id) em execução."
    }
    catch {
        throw "[Servico] Falha ao iniciar GpuEngineService.exe: $_"
    }
}

function Get-RelativePath([string]$basePath, [string]$fullPath) {
    $normalizedBase = (Resolve-Path $basePath -ErrorAction Stop).ProviderPath
    if(-not $normalizedBase.EndsWith("\") -and -not $normalizedBase.EndsWith("/")) {
        $normalizedBase += "\"
    }
    return $fullPath.Substring($normalizedBase.Length).TrimStart('\','/')
}

function Ensure-Directory {
    param([string]$Path)
    if(-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Confirm-Yes([string]$Prompt) {
    $response = (Read-Host $Prompt).Trim().ToLowerInvariant()
    return ($response -eq "s" -or $response -eq "sim" -or $response -eq "y" -or $response -eq "yes")
}

function Compare-Directories {
    param(
        [string]$Label,
        [string]$Source,
        [string]$Target,
        [bool]$Recursive = $true,
        [string[]]$Extensions = $null,
        [switch]$OfferFix
    )

    Write-Host ""
    Write-Host "[Doctor][$Label] Fonte   : $Source"
    Write-Host "[Doctor][$Label] Destino : $Target"

    if(-not (Test-Path $Source)) {
        Write-Warning "[Doctor][$Label] Fonte inexistente."
        return
    }

    $targetExists = Test-Path $Target
    if(-not $targetExists) {
        Write-Warning "[Doctor][$Label] Destino inexistente."
    }

    $sourceItems = if($Recursive) {
        Get-ChildItem -Path $Source -File -Recurse
    } else {
        Get-ChildItem -Path $Source -File
    }

    if($Extensions) {
        $extSet = $Extensions | ForEach-Object { $_.ToLower() }
        $sourceItems = $sourceItems | Where-Object { $extSet -contains $_.Extension.ToLower() }
    }

    $sourceList = @($sourceItems)
    $targetList = @()
    $targetMap  = @{}

    if($targetExists) {
        $targetList = if($Recursive) {
            Get-ChildItem -Path $Target -File -Recurse
        } else {
            Get-ChildItem -Path $Target -File
        }
        if($Extensions) {
            $targetList = $targetList | Where-Object { $extSet -contains $_.Extension.ToLower() }
        }

        foreach($item in $targetList) {
            $rel = Get-RelativePath -basePath $Target -fullPath $item.FullName
            $targetMap[$rel.ToLower()] = $item
        }
    }

    $missing = @()
    $different = @()

    foreach($src in $sourceList) {
        $rel = Get-RelativePath -basePath $Source -fullPath $src.FullName
        $key = $rel.ToLower()
        if(-not $targetMap.ContainsKey($key)) {
            $missing += $rel
            continue
        }
        $dst = $targetMap[$key]
        $targetMap.Remove($key) | Out-Null

        $sizeMatch = ($src.Length -eq $dst.Length)
        $timeDiff = [Math]::Abs(($src.LastWriteTimeUtc - $dst.LastWriteTimeUtc).TotalSeconds)
        if(-not $sizeMatch -or $timeDiff -gt 2) {
            $different += [PSCustomObject]@{
                RelativePath = $rel
                SourceSize   = $src.Length
                TargetSize   = $dst.Length
                SourceTime   = $src.LastWriteTime
                TargetTime   = $dst.LastWriteTime
                SourcePath   = $src.FullName
                TargetPath   = $dst.FullName
            }
        }
    }

    $extra = @()
    foreach($value in $targetMap.Values) {
        $rel = Get-RelativePath -basePath $Target -fullPath $value.FullName
        $candidate = Join-Path $Source $rel
        if(Test-Path -LiteralPath $candidate) {
            continue
        }
        $extra += $value
    }

    if($missing.Count -eq 0 -and $different.Count -eq 0 -and $extra.Count -eq 0) {
        Write-Host "[Doctor][$Label] OK - nenhuma divergencia encontrada."
        return
    }

    if($missing.Count -gt 0) {
        Write-Warning "[Doctor][$Label] Ausentes no destino: $($missing.Count)"
        foreach($item in $missing) {
            Write-Host "    [-] $item"
        }
    }

    if($different.Count -gt 0) {
        Write-Warning "[Doctor][$Label] Diferencas detectadas: $($different.Count)"
        foreach($entry in $different) {
            Write-Host ("    [!] {0} | tam fonte={1} dest={2} | mod fonte={3:yyyy-MM-dd HH:mm:ss} dest={4:yyyy-MM-dd HH:mm:ss}" -f `
                $entry.RelativePath, $entry.SourceSize, $entry.TargetSize, $entry.SourceTime, $entry.TargetTime)
        }
    }

    if($extra.Count -gt 0) {
        Write-Warning "[Doctor][$Label] Arquivos somente no destino: $($extra.Count)"
        foreach($item in $extra) {
            $rel = Get-RelativePath -basePath $Target -fullPath $item.FullName
            Write-Host ("    [+] {0} (tam={1} mod={2:yyyy-MM-dd HH:mm:ss})" -f $rel, $item.Length, $item.LastWriteTime)
        }
    }

    if(-not $OfferFix) {
        return
    }

    if($missing.Count -gt 0 -or $different.Count -gt 0) {
        if(Confirm-Yes "[Doctor][$Label] Copiar arquivos ausentes/diferentes do fonte para o destino? (s/N)") {
            foreach($rel in $missing) {
                $srcPath = Join-Path $Source $rel
                $dstPath = Join-Path $Target $rel
                $dstDir  = Split-Path $dstPath -Parent
                Ensure-Directory $dstDir
                Write-Host ("    -> Copiando {0}" -f $rel)
                Copy-Item -Path $srcPath -Destination $dstPath -Force
            }
            foreach($entry in $different) {
                $dstDir = Split-Path $entry.TargetPath -Parent
                Ensure-Directory $dstDir
                Write-Host ("    -> Atualizando {0}" -f $entry.RelativePath)
                Copy-Item -Path $entry.SourcePath -Destination $entry.TargetPath -Force
            }
        }
    }

    if($extra.Count -gt 0) {
        Write-Host "    (Arquivos presentes apenas no destino)"
        if(Confirm-Yes "[Doctor][$Label] Copiar arquivos extras do destino de volta para o source (Dev)? (s/N)") {
            foreach($item in $extra) {
                $rel = Get-RelativePath -basePath $Target -fullPath $item.FullName
                $srcPath = $item.FullName
                $dstPath = Join-Path $Source $rel
                $dstDir = Split-Path $dstPath -Parent
                Ensure-Directory $dstDir
                Write-Host ("    -> Copiando {0} -> {1}" -f $rel, $dstPath)
                Copy-Item -Path $srcPath -Destination $dstPath -Force
            }
        } else {
            Write-Host "    (Nenhuma ação tomada; arquivo extra permanece no destino)"
        }
    }
}

function Invoke-DoctorLinksDetailed {
    Write-Host ""
    Write-Host "[Doctor] Verificando juncoes e arquivos definidos em links_config.json"

    $linksConfigPath = Join-Path $scriptRoot "links_config.json"
    if(-not (Test-Path $linksConfigPath)) {
        Write-Warning "[Doctor] links_config.json nao encontrado."
        return
    }

    $configJson = Get-Content $linksConfigPath -Raw | ConvertFrom-Json
    if(-not $configJson) {
        Write-Warning "[Doctor] links_config.json vazio."
        return
    }

    $scriptDirInfo = Get-Item $scriptRoot
    $terminalGuidDir = $scriptDirInfo.Parent.Parent
    $terminalRoot = $terminalGuidDir.Parent

    $terminalDirs = @()
    if(Test-Path $terminalRoot) {
        $terminalDirs = Get-ChildItem $terminalRoot -Directory |
            Where-Object { $_.Name -match '^[0-9A-Fa-f]{32}$' }
    }

    if($terminalGuidDir -and ($terminalGuidDir.Name -match '^[0-9A-Fa-f]{32}$')) {
        if(-not ($terminalDirs | Where-Object { $_.FullName -eq $terminalGuidDir.FullName })) {
            $terminalDirs += $terminalGuidDir
        }
    }

    if($terminalDirs.Count -eq 0) {
        Write-Warning "[Doctor] Nenhuma instancia de Terminal (<GUID>) encontrada."
        return
    }

    foreach($guidDir in $terminalDirs) {
        Write-Host ""
        Write-Host "[Doctor][Links] Instancia $($guidDir.Name)"
        foreach($entry in $configJson) {
            $sourceFull = [System.IO.Path]::GetFullPath((Join-Path $scriptRoot $entry.Source))
            $targetRaw  = $entry.Target -replace "<GUID>", $guidDir.Name
            $targetFull = [System.IO.Path]::GetFullPath($targetRaw)

            Write-Host "  - Fonte : $sourceFull"
            Write-Host "    Alvo  : $targetFull"

            $sourceExists = Test-Path $sourceFull
            if(-not $sourceExists) {
                Write-Warning "    [!] Fonte inexistente."
            }

            $targetItem = Get-Item -LiteralPath $targetFull -Force -ErrorAction SilentlyContinue
            if(-not $targetItem) {
                Write-Warning "    [!] Alvo inexistente."
                continue
            }

            $isReparse = ($targetItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
            $expectedType = $entry.Type

            if($expectedType -eq "Directory") {
                if(-not $isReparse) {
                    Write-Warning "    [!] Esperado junction/diretorio linkado, mas alvo nao e reparse point."
                } else {
                    $linkTarget = $null
                    try { $linkTarget = $targetItem.Target } catch { }
                    if($linkTarget) {
                        Write-Host "    Tipo  : Junction -> $linkTarget"
                    } else {
                        Write-Host "    Tipo  : Junction (destino nao informado)."
                    }
                }
                Write-Host ("    Atual: criado={0:yyyy-MM-dd HH:mm:ss} mod={1:yyyy-MM-dd HH:mm:ss}" -f `
                    $targetItem.CreationTime, $targetItem.LastWriteTime)
            }
            else {
                if($isReparse) {
                    Write-Warning "    [!] Esperado arquivo, mas o alvo e um reparse point."
                }
                $targetSize = $targetItem.Length
                $targetTime = $targetItem.LastWriteTime
                Write-Host ("    Atual: tamanho={0} mod={1:yyyy-MM-dd HH:mm:ss}" -f $targetSize, $targetTime)

                if($sourceExists) {
                    $sourceItem = Get-Item -LiteralPath $sourceFull -Force
                    if($sourceItem.Length -ne $targetSize) {
                        Write-Warning ("    [!] Tamanho divergente (fonte={0} dest={1})." -f $sourceItem.Length, $targetSize)
                    }
                    $timeDiff = [Math]::Abs(($sourceItem.LastWriteTimeUtc - $targetItem.LastWriteTimeUtc).TotalSeconds)
                    if($timeDiff -gt 2) {
                        Write-Warning ("    [!] Horario de modificacao diferente (fonte={0:yyyy-MM-dd HH:mm:ss} dest={1:yyyy-MM-dd HH:mm:ss})." -f `
                            $sourceItem.LastWriteTime, $targetItem.LastWriteTime)
                    }
                }
            }
        }
    }
}

function Invoke-DoctorDetailed {
    param([switch]$Auto)

    Write-Host ""
    Write-Host "[Doctor] Auditoria detalhada de artefatos e links"

    $pairs = @(
        @{ Label = "Binarios (Dev/bin vs runtime/bin)"; Source = Join-Path $scriptRoot "Dev/bin"; Target = Join-Path $scriptRoot "runtime/bin"; Recursive = $false; Extensions = @(".dll", ".exe", ".lib", ".pdb") },
        @{ Label = "Indicators"; Source = Join-Path $scriptRoot "Dev/Indicators"; Target = Join-Path $scriptRoot "runtime/Indicators"; Recursive = $true; Extensions = @(".mq5", ".ex5") },
        @{ Label = "Experts"; Source = Join-Path $scriptRoot "Dev/Experts"; Target = Join-Path $scriptRoot "runtime/Experts"; Recursive = $true; Extensions = @(".mq5", ".ex5") },
        @{ Label = "Include"; Source = Join-Path $scriptRoot "Dev/Include"; Target = Join-Path $scriptRoot "runtime/Include"; Recursive = $true; Extensions = @(".mqh", ".mq5") },
        @{ Label = "Scripts"; Source = Join-Path $scriptRoot "Dev/Scripts"; Target = Join-Path $scriptRoot "runtime/Scripts"; Recursive = $true; Extensions = @(".mq5", ".ex5") }
    )

    foreach($pair in $pairs) {
        Compare-Directories -Label $pair.Label -Source $pair.Source -Target $pair.Target -Recursive $pair.Recursive -Extensions $pair.Extensions -OfferFix:(!$Auto)
    }

    Invoke-DoctorLinksDetailed
    Write-Host ""
    Write-Host "[Doctor] Auditoria concluida."
}

function Invoke-PipelineService {
    Write-Host ""; Write-Host "[Pipeline] Build -> Sync -> Links -> Doctor -> Serviço"

    $report = New-Object System.Collections.Generic.List[object]

    function Run-Step {
        param(
            [string]$Label,
            [scriptblock]$Action,
            [switch]$CheckExitCode
        )

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            & $Action
            if($CheckExitCode -and $LASTEXITCODE -ne 0) {
                throw "Código de saída $LASTEXITCODE"
            }
            $sw.Stop()
            $report.Add([PSCustomObject]@{
                Etapa   = $Label
                Status  = "OK"
                Tempo_s = [Math]::Round($sw.Elapsed.TotalSeconds, 2)
                Mensagem= ""
            })
        }
        catch {
            $sw.Stop()
            $msg = ($_.Exception.Message -replace '\s+', ' ').Trim()
            $report.Add([PSCustomObject]@{
                Etapa   = $Label
                Status  = "FALHA"
                Tempo_s = [Math]::Round($sw.Elapsed.TotalSeconds, 2)
                Mensagem= $msg
            })
            throw
        }
    }

    Run-Step "Parar serviço" { Stop-GpuServiceIfRunning }
    Run-Step "Build" { Invoke-Build } -CheckExitCode
    Run-Step "Watchdog arquivos" { Invoke-WatchdogSync } -CheckExitCode
    Run-Step "Links -> Dev" { Invoke-SetupRuntimeLinks -Mode "Dev" }
    Run-Step "Watchdog links" { Invoke-FixLinks } -CheckExitCode
    Run-Step "Doctor (auto)" { Invoke-DoctorDetailed -Auto }
    Run-Step "Iniciar serviço" { Invoke-StartService }

    Write-Host ""
    Write-Host "[Relatório do pipeline]"
    $report | Format-Table -AutoSize
}

function Show-Menu {
    Write-Host ""
    Write-Host "WaveSpec GPU - CLI de Desenvolvimento"
    Write-Host "-------------------------------------"
    Write-Host "Pipelines"
    Write-Host "  [1] Pipeline completo (Build -> Sync -> Links -> Doctor -> Serviço)"
    Write-Host "      • Build -> Watchdog Dev→runtime -> SetupRuntimeLinks -> WatchdogLinks --fix -> Doctor --auto -> reinicia serviço."
    Write-Host "  [9] Pipeline completo + agentes"
    Write-Host "      • Opção 1 seguida de SetupAgentTesterLinks.ps1."
    Write-Host "  [10] Doctor (Dev/runtime + links)"
    Write-Host "      • Compara Dev vs runtime, oferece copiar/atualizar e valida links_config.json."
    Write-Host ""
    Write-Host "Build e sincronização"
    Write-Host "  [2] Build (usar cache atual)"
    Write-Host "      • Build.ps1 sem limpar build_vs (reaproveita configuração/pastas existentes)."
    Write-Host "  [3] Build (limpo)"
    Write-Host "      • Build.ps1 -Clean (remove build_vs, reconfigura CMake e recompila tudo)."
    Write-Host "  [4] Watchdog Dev -> runtime"
    Write-Host "      • WatchdogFiles_dev_to_runtime.py --apply --once (Indicators/Experts/Include/Scripts + binários)."
    Write-Host "  [6] WatchdogLinks_runtime_m5folders.py --fix"
    Write-Host "      • Ajusta junções das instâncias MetaTrader (Include/Indicators/Experts/Scripts/Libraries apontando para Dev/ e Dev/bin)."
    Write-Host "  [5] SetupAgentTesterLinks.ps1"
    Write-Host "      • Recria junções dos agentes tester (PowerShell admin)."
    Write-Host ""
    Write-Host "Serviço"
    Write-Host "  [8] Reiniciar GpuEngineService.exe (modo usuário)"
    Write-Host "      • Stop-Process GpuEngineService → Start-Process runtime/bin\GpuEngineService.exe."
    Write-Host ""
    Write-Host "Links das instâncias"
    Write-Host "  [11] Links -> Dev (padrão desenvolvimento)"
    Write-Host "      • Recria junções apontando para Dev/ e Dev/bin."
    Write-Host "  [12] Links -> runtime (modo testes)"
    Write-Host "      • Reaponta junções para runtime/ (útil quando o tester bloqueia DLLs do Dev/)."
    Write-Host "  [13] Links -> caminho customizado"
    Write-Host "      • Solicita um diretório base e recria as junções apontando para ele."
    Write-Host ""
    Write-Host "[14] Sair"
    Write-Host ""
    Write-Host "Use ?<opcao> (ex.: ?1) ou 'info <opcao>' para ver os detalhes sem executar."
    Write-Host ""
} 

if($Run -and $Run.Count -gt 0) {
    $script:CliAutoMode = $true
    for($i = 0; $i -lt $Run.Count; $i++) {
        $entry = $Run[$i]
        if(Process-DetailRequest -InputValue $entry) { continue }

        if($entry -eq "13" -and ($i + 1) -lt $Run.Count) {
            $next = $Run[$i + 1]
            if($next -notmatch '^(\d+)([=:].*)?$') {
                $continue = Execute-Option -Choice "13" -CustomArgOverride $next
                $i++
                if(-not $continue) { break }
                continue
            }
        }

        $continue = Execute-Option -Choice $entry
        if(-not $continue) { break }
    }
    return
}

$script:CliAutoMode = $false

while($true) {
    Show-Menu
    $choice = Read-Host "[CLI] Escolha uma opcao"
    if(Process-DetailRequest -InputValue $choice) { continue }
    $shouldContinue = Execute-Option -Choice $choice
    if(-not $shouldContinue) { break }
}
