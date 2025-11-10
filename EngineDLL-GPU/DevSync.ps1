[CmdletBinding()]
param(
    [switch]$All,
    [switch]$Snapshot,
    [string]$Label,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$scriptRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path
$devRoot     = Join-Path $scriptRoot "Dev"
$runtimeRoot = Join-Path $scriptRoot "runtime"
$versionRoot = Join-Path $scriptRoot "Versionamento"

function Assert-Exists([string]$Path, [string]$Name) {
    if(-not (Test-Path $Path)) {
        throw "$Name nao localizado em '$Path'."
    }
}

Assert-Exists $devRoot "Dev/"

if(-not (Test-Path $runtimeRoot)) {
    New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
}

if(-not (Test-Path $versionRoot)) {
    New-Item -ItemType Directory -Path $versionRoot -Force | Out-Null
}

Write-Host ("fazendo copia de {0} -> {1}..." -f $devRoot, $runtimeRoot)
if($DryRun) {
    Write-Host "modo dry-run: arquivos nao serão copiados."
} else {
    if($All -and (Test-Path $runtimeRoot)) {
        Write-Host ("  limpando destino {0}..." -f $runtimeRoot)
        Remove-Item $runtimeRoot -Recurse -Force
        New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
    }
    Copy-Item -Path (Join-Path $devRoot '*') -Destination $runtimeRoot -Recurse -Force
}

if($Snapshot) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    if([string]::IsNullOrWhiteSpace($Label)) {
        $label = $timestamp
    } else {
        $safeLabel = ($Label -replace '[^a-zA-Z0-9_\-]', '_')
        $label = "${timestamp}_$safeLabel"
    }
    $snapshotDir = Join-Path $versionRoot $label
    if(Test-Path $snapshotDir) {
        throw "Snapshot '$snapshotDir' já existe."
    }
    Write-Host ("fazendo snapshot de {0} -> {1}..." -f $devRoot, $snapshotDir)
    if($DryRun) {
        Write-Host "modo dry-run: snapshot nao será criado."
    } else {
        New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
        Copy-Item -Path (Join-Path $devRoot '*') -Destination $snapshotDir -Recurse -Force
        Write-Host ("  snapshot concluido: {0}" -f $snapshotDir)
    }
}

Write-Host "concluido."
