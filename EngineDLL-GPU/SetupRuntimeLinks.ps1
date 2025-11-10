[CmdletBinding()]
param(
    [switch]$DryRun,
    [ValidateSet("Dev","Runtime","Custom")]
    [string]$SourceMode = "Dev",
    [string]$CustomRoot
)

$ErrorActionPreference = "Stop"

$scriptRoot  = $PSScriptRoot
$runtimeRoot = Join-Path $scriptRoot "runtime"
$binRuntime  = Join-Path $runtimeRoot "bin"
$devRoot     = Join-Path $scriptRoot "Dev"
$devBin      = Join-Path $devRoot "bin"
$logDir      = Join-Path $scriptRoot "logs"
$logFile     = Join-Path $logDir "SetupRuntimeLinks.log"

if(-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-Log([string]$message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value ("{0} | {1}" -f $timestamp, $message)
}

function Write-Step([string]$msg) {
    Write-Host $msg
}

if(-not (Test-Path $runtimeRoot)) {
    throw "runtime/ não encontrado em '$runtimeRoot'."
}

if(-not (Test-Path $binRuntime)) {
    throw "runtime/bin não encontrado em '$binRuntime'."
}

if(-not (Test-Path $devRoot)) {
    throw "Dev/ não encontrado em '$devRoot'."
}

if(-not (Test-Path $devBin)) {
    throw "Dev/bin não encontrado em '$devBin'."
}

Write-Log ("BEGIN SetupRuntimeLinks (DryRun={0}, Mode={1})" -f $DryRun.IsPresent, $SourceMode)

$linksFile = Join-Path $scriptRoot "links_config.json"
if(-not (Test-Path $linksFile)) {
    $sample = @(
        @{ Target = "C:\Users\pichau\AppData\Roaming\MetaQuotes\Terminal\<GUID>\MQL5\Indicators"; Source = "Dev\Indicators"; Type = "Directory" },
        @{ Target = "C:\Users\pichau\AppData\Roaming\MetaQuotes\Terminal\<GUID>\MQL5\Experts"; Source = "Dev\Experts"; Type = "Directory" },
        @{ Target = "C:\Users\pichau\AppData\Roaming\MetaQuotes\Terminal\<GUID>\MQL5\Include"; Source = "Dev\Include"; Type = "Directory" },
    @{ Target = "C:\Users\pichau\AppData\Roaming\MetaQuotes\Terminal\<GUID>\MQL5\Libraries"; Source = "Dev\bin"; Type = "Directory" },
        @{ Target = "C:\Users\pichau\AppData\Roaming\MetaQuotes\Terminal\<GUID>\Services\GpuEngineService.exe"; Source = "Dev\bin\GpuEngineService.exe"; Type = "File" },
        @{ Target = "C:\Users\pichau\AppData\Roaming\MetaQuotes\Terminal\<GUID>\MQL5\Files\WaveSpecGPU\logs"; Source = "logs"; Type = "Directory" }
    ) | ConvertTo-Json -Depth 4
    Write-Host "links_config.json não encontrado. Criando exemplo..."
    $sample | Set-Content -Path $linksFile -Encoding UTF8
    throw "Crie links_config.json com as entradas desejadas e execute novamente."
}

$data = Get-Content -Path $linksFile -Raw | ConvertFrom-Json
if(-not $data) {
    throw "links_config.json vazio."
}

[char[]]$invalidChars = [System.IO.Path]::GetInvalidPathChars()

switch($SourceMode) {
    "Dev" { }
    "Runtime" { }
    "Custom" {
        if(-not $CustomRoot) {
            throw "CustomRoot obrigatorio quando SourceMode=Custom."
        }
        try {
            $script:ResolvedCustomRoot = [System.IO.Path]::GetFullPath($CustomRoot)
        } catch {
            throw "Nao foi possivel resolver CustomRoot '$CustomRoot': $($_.Exception.Message)"
        }
        if(-not (Test-Path -LiteralPath $script:ResolvedCustomRoot)) {
            Write-Warning "CustomRoot '$script:ResolvedCustomRoot' inexistente."
        }
    }
}

function Resolve-SourcePath {
    param([string]$SourceRel)

    switch($SourceMode) {
        "Dev" {
            return Join-Path $scriptRoot $SourceRel
        }
        "Runtime" {
            if($SourceRel -match '^(?i)dev([\\/].*)$') {
                $suffix = $Matches[1]
                return Join-Path $scriptRoot ("runtime" + $suffix)
            }
            if($SourceRel -ieq 'dev') {
                return Join-Path $scriptRoot "runtime"
            }
            return Join-Path $scriptRoot $SourceRel
        }
        "Custom" {
            $base = $script:ResolvedCustomRoot
            if($SourceRel -match '^(?i)dev[\\/](.*)$') {
                $rel = $Matches[1]
                return Join-Path $base $rel
            }
            if($SourceRel -ieq 'dev') {
                return $base
            }
            return Join-Path $base $SourceRel
        }
    }
}

$scriptDirInfo   = Get-Item $scriptRoot
$terminalGuidDir = $scriptDirInfo.Parent.Parent
$terminalRoot    = $terminalGuidDir.Parent

$guidDirs = @()
if($terminalRoot -and (Test-Path $terminalRoot)) {
    $guidDirs = Get-ChildItem $terminalRoot -Directory |
        Where-Object { $_.Name -match '^[0-9A-Fa-f]{32}$' }
}

if($terminalGuidDir -and ($terminalGuidDir.Name -match '^[0-9A-Fa-f]{32}$')) {
    if(-not ($guidDirs | Where-Object { $_.FullName -eq $terminalGuidDir.FullName })) {
        $guidDirs += $terminalGuidDir
    }
}

if($guidDirs.Count -eq 0) {
    throw "Nenhuma instância de Terminal (<GUID>) encontrada. Ajuste a estrutura ou links_config.json."
}

function Invoke-LinkCreation {
    param(
        [string]$TargetPath,
        [string]$SourcePath,
        [string]$Type
    )

    $normalizedTarget = try {
        [System.IO.Path]::GetFullPath($TargetPath)
    } catch {
        throw "Destino '$TargetPath' inválido: $($_.Exception.Message)"
    }

    if($normalizedTarget.IndexOfAny($invalidChars) -ge 0) {
        throw "Destino '$normalizedTarget' contém caracteres inválidos. Revise links_config.json."
    }

    Write-Step "fazendo link: $normalizedTarget -> $SourcePath"
    Write-Log  ("PROCESS {0} -> {1} (Type={2})" -f $normalizedTarget, $SourcePath, $Type)

    $targetExists = Test-Path -LiteralPath $normalizedTarget
    if($targetExists) {
        $item = Get-Item -LiteralPath $normalizedTarget -Force
        $isReparse = ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
        if($isReparse) {
            $currentTarget = $null
            try {
                $currentTarget = ($item | Select-Object -ExpandProperty Target)
            } catch {
                $currentTarget = $null
            }
            if(-not $currentTarget -and $item.PSIsContainer) {
                try {
                    $currentTarget = (Resolve-Path -LiteralPath $normalizedTarget).ProviderPath
                } catch { }
            }
            if($currentTarget -and ($currentTarget -ieq $SourcePath)) {
                Write-Host "  já era link correto; mantendo."
                Write-Log  ("SKIP existing junction {0} (already -> {1})" -f $normalizedTarget, $SourcePath)
                return
            }

            Write-Host "  já era link; removendo para recriar."
            Write-Log  ("REMOVE existing junction {0}" -f $normalizedTarget)
            if(-not $DryRun) {
                try {
                    Remove-Item -LiteralPath $normalizedTarget -Force
                }
                catch {
                    if($item.PSIsContainer) {
                        Remove-Item -LiteralPath $normalizedTarget -Force -Recurse
                    } else {
                        throw
                    }
                }
            }
        } else {
            Write-Host "  destino existe. movendo para backup."
            Write-Log  ("MOVE existing item {0}" -f $normalizedTarget)
            if(-not $DryRun) {
                $backup = "{0}.backup_{1:yyyyMMdd_HHmmss}" -f $normalizedTarget, (Get-Date)
                Move-Item -LiteralPath $normalizedTarget -Destination $backup -Force
                Write-Log  ("BACKUP {0} -> {1}" -f $normalizedTarget, $backup)
            }
        }
    }

    $parent = Split-Path -Parent $normalizedTarget
    if(-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        Write-Log ("CREATE parent directory {0}" -f $parent)
    }

    if($DryRun) {
        Write-Host "  modo dry-run: link não criado."
        Write-Log  ("DRYRUN create link {0} -> {1}" -f $normalizedTarget, $SourcePath)
        return
    }

    if($Type -eq "Directory") {
        New-Item -ItemType Junction -Path $normalizedTarget -Target $SourcePath -Force | Out-Null
        Write-Log ("JUNCTION {0} -> {1}" -f $normalizedTarget, $SourcePath)
    } else {
        Copy-Item -LiteralPath $SourcePath -Destination $normalizedTarget -Force
        Write-Log ("COPY {0} -> {1}" -f $SourcePath, $normalizedTarget)
    }

    Write-Host "  concluído."
}

foreach($entry in $data) {
    $target = $entry.Target
    $sourceRel = $entry.Source
    $type = $entry.Type

    if([string]::IsNullOrWhiteSpace($target) -or [string]::IsNullOrWhiteSpace($sourceRel)) {
        Write-Warning "Entrada inválida: Target ou Source vazios. Pulando."
        continue
    }

    $sourcePath = Resolve-SourcePath $sourceRel
    if(-not (Test-Path -LiteralPath $sourcePath)) {
        Write-Warning "Fonte '$sourcePath' não encontrada (SourceMode=$SourceMode). Pulando $target."
        Write-Log ("SKIP missing source {0} -> {1} (mode={2})" -f $target, $sourcePath, $SourceMode)
        continue
    }
    $source = (Resolve-Path -LiteralPath $sourcePath).ProviderPath

    $targetsToProcess = @()
    if($target -like "*<GUID>*") {
        foreach($guidDir in $guidDirs) {
            $expanded = $target -replace "<GUID>", $guidDir.Name
            $targetsToProcess += $expanded
        }
    } else {
        $targetsToProcess += $target
    }

    foreach($targetCandidate in $targetsToProcess) {
        Invoke-LinkCreation -TargetPath $targetCandidate -SourcePath $source -Type $type
    }
}

Write-Host "concluído."
Write-Log "END SetupRuntimeLinks"
