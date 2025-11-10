[CmdletBinding()]
param(
    [string]$CompiledFile
)

$ErrorActionPreference = "Stop"

function Resolve-Python {
    foreach($candidate in @("python", "python3")) {
        $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
        if($cmd) { return $cmd.Path }
    }
    throw "Python nao encontrado no PATH."
}

try {
    $repoRoot = $PSScriptRoot
    $python = Resolve-Python
    $watchdog = Join-Path $repoRoot "watchdogs/WatchdogFiles_dev_to_runtime.py"
    if(-not (Test-Path $watchdog)) {
        throw "Script de watchdog nao encontrado: $watchdog"
    }

    Write-Host "[after-compile] atualizando runtime/ e agentes..."
    & $python $watchdog --apply --once --quiet
    if($CompiledFile) {
        Write-Host "[after-compile] compilado: $CompiledFile"
    }
    Write-Host "[after-compile] concluido."
} catch {
    Write-Warning "[after-compile] falha: $($_.Exception.Message)"
    exit 1
}
