# AVISO: Os agentes do Strategy Tester ficam APENAS nos diretórios de instalação do MetaTrader
# (ex.: C:\Program Files\MetaTrader 5\Tester\Agent-0.0.0.0-2000). NUNCA configure agentes
# dentro das pastas GUID em %APPDATA%\MetaQuotes\Terminal\<GUID>.
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$scriptRoot = $PSScriptRoot
$agentsRoot = Join-Path $scriptRoot "AgentsFiles-to-tester_folder_terminals"

$repoLibrariesPath = Join-Path $scriptRoot "..\Libraries"
try {
    $repoLibraries = (Resolve-Path $repoLibrariesPath -ErrorAction Stop).Path
} catch {
    throw "Diretorio de bibliotecas base nao encontrado: $repoLibrariesPath"
}

if(-not (Test-Path $agentsRoot)) {
    throw "Diretorio '$agentsRoot' nao encontrado."
}

$slotPaths = @(
    "Shared\Slot01/MQL5/Libraries",
    "Shared\Slot02/MQL5/Libraries",
    "Shared\Slot03/MQL5/Libraries",
    "Shared\Slot04/MQL5/Libraries",
    "Shared\Slot05/MQL5/Libraries",
    "Shared\Slot06/MQL5/Libraries",
    "Shared\Slot07/MQL5/Libraries",
    "Shared\Slot08/MQL5/Libraries",
    "Shared\Slot09/MQL5/Libraries",
    "Shared\Slot10/MQL5/Libraries",
    "Shared\Slot11/MQL5/Libraries",
    "Shared\Slot12/MQL5/Libraries"
)

$agentNumbers = 2000..2011

function Sync-AgentLibraries([string]$targetDir) {
    # AVISO: manter apenas bibliotecas vindas de MQL5\Libraries; nao copie arquivos dos GUIDs.
    if(Test-Path $targetDir) {
        Get-ChildItem $targetDir -File -ErrorAction SilentlyContinue | Remove-Item -Force
    } else {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    Write-Host "[sync] atualizando $targetDir"

    Get-ChildItem $repoLibraries -File | ForEach-Object {
        Copy-Item $_.FullName -Destination (Join-Path $targetDir $_.Name) -Force
    }
}

function Ensure-LibrariesLink([string]$agentBase, [string]$sourceDir) {
    # AVISO: as juncoes devem apontar somente para os diretórios de agente em Program Files.
    if(-not (Test-Path $agentBase)) {
        Write-Host "[links] info: instancia '$($inst.Name)' sem agente: $agentBase (ignorado)"
        return
    }
    if(-not (Test-Path $sourceDir)) {
        Write-Host "[links] info: fonte nao encontrada (ignorado): $sourceDir"
        return
    }

    $librariesPath = Join-Path $agentBase "MQL5\Libraries"
    if(Test-Path $librariesPath) {
        $item = Get-Item $librariesPath -ErrorAction SilentlyContinue
        if($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            $currentTarget = try { (Get-Item $librariesPath -Force).Target } catch { $null }
            if($currentTarget) {
                $resolved = try { (Resolve-Path $currentTarget -ErrorAction SilentlyContinue).ProviderPath } catch { $null }
                if($resolved -eq (Resolve-Path $sourceDir).ProviderPath) {
                    Write-Host "[links] OK: $librariesPath -> $sourceDir"
                    return
                }
            }
            Write-Host "[links] substituindo link existente: $librariesPath"
            Remove-Item $librariesPath -Force
        } else {
            Write-Host "[links] movendo conteudo atual para backup: $librariesPath"
            $backup = "${librariesPath}_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Move-Item $librariesPath $backup -Force
        }
    }

    $parent = Split-Path -Parent $librariesPath
    if(-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Write-Host "[links] criando link: $librariesPath -> $sourceDir"
    try {
        New-Item -ItemType Junction -Path $librariesPath -Target $sourceDir -Force | Out-Null
    }
    catch {
        Write-Warning "[links] falha ao criar junction: $_"
    }
}

if($slotPaths.Count -ne $agentNumbers.Count) {
    throw "Quantidade de slots ($($slotPaths.Count)) difere da quantidade de agentes ($($agentNumbers.Count))."
}

$absoluteSlots = @()
for($i = 0; $i -lt $slotPaths.Count; $i++) {
    $slotPath = Join-Path $agentsRoot $slotPaths[$i]
    Sync-AgentLibraries $slotPath
    $absoluteSlots += $slotPath
}

$installations = @(
    @{ Name = "MetaTrader 5"; Base = "C:\\Program Files\\MetaTrader 5\\Tester" },
    @{ Name = "Dukascopy MetaTrader 5"; Base = "C:\\Program Files\\Dukascopy MetaTrader 5\\Tester" }
)

for($i = 0; $i -lt $agentNumbers.Count; $i++) {
    $agentSuffix = ("Agent-0.0.0.0-{0:0000}" -f $agentNumbers[$i])
    $sourceSlot = $absoluteSlots[$i]
    foreach($inst in $installations) {
        $agentBase = Join-Path $inst.Base $agentSuffix
        if(-not (Test-Path $agentBase)) {
            Write-Host "[links] info: instancia '$($inst.Name)' sem agente: $agentBase (ignorado). Crie via MetaTrader (Ferramentas > Opções > Agentes > Adicionar)." -ForegroundColor DarkYellow
            continue
        }
        Ensure-LibrariesLink $agentBase $sourceSlot
    }
}

Write-Host "[links] configuracao concluida."
