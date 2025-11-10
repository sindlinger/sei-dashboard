# AVISO: Os agentes do Strategy Tester ficam APENAS nos diretórios de instalação do MetaTrader
# (ex.: C:\Program Files\MetaTrader 5\Tester\Agent-0.0.0.0-2000). NUNCA configure agentes
# dentro das pastas GUID em %APPDATA%\MetaQuotes\Terminal\<GUID>.
[CmdletBinding()]
param(
    [string]$BuildDir = "build_vs",
    [ValidateSet("Debug","Release")]
    [string]$Configuration = "Release",
    [switch]$Clean,
    [switch]$SkipConfigure
)

$ErrorActionPreference = "Stop"

$scriptRoot = $PSScriptRoot
$repoRoot   = $scriptRoot
$devRoot    = Join-Path $repoRoot "Dev"

if(-not (Test-Path $devRoot)) {
    throw "Diretorio 'Dev/' nao localizado. Estrutura esperada: Dev/bin, Dev/src, etc."
}

$buildPath = Join-Path $repoRoot $BuildDir
$generator = "Visual Studio 17 2022"

function Resolve-CMake([string]$DesiredGenerator) {
    $candidates = New-Object System.Collections.Generic.List[string]
    if($env:CMAKE_PATH) { $candidates.Add($env:CMAKE_PATH) }

    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if(Test-Path $vswhere) {
        $installPaths = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath 2>$null
        foreach($path in $installPaths) {
            if($path) {
                $candidates.Add((Join-Path $path "Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"))
            }
        }
    }

    $candidates.Add("C:\Program Files\CMake\bin\cmake.exe")
    $candidates.Add("C:\Program Files (x86)\CMake\bin\cmake.exe")

    $cmakeFromPath = Get-Command cmake.exe -ErrorAction SilentlyContinue
    if($cmakeFromPath -and $cmakeFromPath.Source) {
        $candidates.Add($cmakeFromPath.Source)
    }

    $seen = @{}
    foreach($candidate in $candidates) {
        if(-not $candidate) { continue }
        $full = [System.IO.Path]::GetFullPath($candidate)
        if($seen.ContainsKey($full)) { continue }
        $seen[$full] = $true
        if(-not (Test-Path $full)) { continue }
        try {
            $help = & $full --help 2>$null
            if($LASTEXITCODE -ne 0) { continue }
            if($help -match [regex]::Escape($DesiredGenerator)) {
                return $full
            }
        } catch { continue }
    }
    throw "cmake.exe com suporte ao gerador '$DesiredGenerator' nao encontrado."
}

$cmakeExe = Resolve-CMake $generator

if($Clean -and (Test-Path $buildPath)) {
    Write-Host "limpando diretorio de build ($buildPath)..."
    Remove-Item -Path $buildPath -Recurse -Force
}

if(-not $SkipConfigure -or -not (Test-Path $buildPath)) {
    $cmakeArgs = @("-S", $repoRoot, "-B", $buildPath, "-G", $generator, "-A", "x64")
    Write-Host "configurando CMake ($generator)..."
    & $cmakeExe @cmakeArgs
    if($LASTEXITCODE -ne 0) { throw "Configuracao CMake falhou (codigo $LASTEXITCODE)" }
}

$buildArgs = @("--build", $buildPath, "--config", $Configuration)

Write-Host "compilando ($Configuration)..."
& $cmakeExe @buildArgs
if($LASTEXITCODE -ne 0) { throw "Build falhou (codigo $LASTEXITCODE)" }

$devBin = Join-Path $devRoot "bin"
if(-not (Test-Path $devBin)) {
    throw "Compilacao concluida mas 'Dev/bin' nao foi criado. Verifique CMakeLists."
}

function Copy-RuntimeDependency {
    param(
        [string]$FileName,
        [string[]]$SearchRoots
    )
    $destination = Join-Path $devBin $FileName
    if(Test-Path $destination) {
        return $true
    }
    foreach($root in $SearchRoots) {
        if(-not $root) { continue }
        $candidate = Join-Path $root $FileName
        if(Test-Path $candidate) {
            Copy-Item -Path $candidate -Destination $destination -Force
            return $true
        }
    }
    return $false
}

$cudaRoots = @(
    $env:CUDA_PATH,
    $env:CUDA_PATH_V13_0,
    "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.0\bin",
    "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.4\bin"
)

$requiredCudaDlls = @(
    "cudart64_13.dll",
    "cufft64_12.dll",
    "cufftw64_12.dll",
    "cufft64_10.dll"
)

foreach($dll in $requiredCudaDlls) {
    $searchRoots = $cudaRoots
    if($dll -eq "cufft64_10.dll") {
        $fallbackRoots = @(
            (Join-Path $repoRoot "waveviz_gpu_dev\Libraries"),
            (Join-Path $repoRoot "legacy_mql_gpu_original_dev\Libraries"),
            (Join-Path $repoRoot "legacy_mql_gpu_original_runtime\Libraries")
        )
        $searchRoots = $searchRoots + $fallbackRoots
    }

    $copied = Copy-RuntimeDependency -FileName $dll -SearchRoots $searchRoots
    if(-not $copied) {
        Write-Warning "Dependencia CUDA '$dll' nao encontrada nos caminhos configurados."
    } else {
        Write-Host "dependencia '$dll' copiada para Dev\\bin"
    }
}

$vcRuntimeRoots = @(
    "C:\Windows\System32"
)

$requiredVcRuntimeDlls = @(
    "msvcp140.dll",
    "vcruntime140.dll",
    "vcruntime140_1.dll",
    "ucrtbase.dll"
)

foreach($dll in $requiredVcRuntimeDlls) {
    $copied = Copy-RuntimeDependency -FileName $dll -SearchRoots $vcRuntimeRoots
    if(-not $copied) {
        Write-Warning "Dependencia VC++ '$dll' nao encontrada em: $($vcRuntimeRoots -join ', ')"
    } else {
        Write-Host "dependencia '$dll' copiada para Dev\\bin"
    }
}

$runtimeBin = Join-Path $repoRoot "runtime/bin"
if(-not (Test-Path $runtimeBin)) {
    New-Item -ItemType Directory -Path $runtimeBin | Out-Null
}

foreach($dll in $requiredCudaDlls + $requiredVcRuntimeDlls) {
    $devPath = Join-Path $devBin $dll
    if(Test-Path $devPath) {
        Copy-Item -Path $devPath -Destination (Join-Path $runtimeBin $dll) -Force
    }
}

Write-Host "artefatos disponiveis em Dev\\bin."
Write-Host "concluido."
