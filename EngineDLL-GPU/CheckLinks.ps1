[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$Path = ".",

    [switch]$Recurse,

    [switch]$IncludeFiles,

    [switch]$IncludeDirectories,

    [switch]$Summary
)

$ErrorActionPreference = "Stop"

if(-not (Test-Path $Path)) {
    throw "Caminho '$Path' não encontrado."
}

$resolvedPath = (Resolve-Path $Path).ProviderPath

function Is-ReparsePointFile {
    param([System.IO.FileSystemInfo]$Item)
    return (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Matches-Type {
    param([System.IO.FileSystemInfo]$Item)
    if($Item.PSIsContainer) {
        return $IncludeDirectories.IsPresent -or (-not $IncludeFiles.IsPresent -and -not $IncludeDirectories.IsPresent)
    } else {
        return $IncludeFiles.IsPresent -or (-not $IncludeFiles.IsPresent -and -not $IncludeDirectories.IsPresent)
    }
}

Write-Host "fazendo varredura de links em $resolvedPath..."

$searchOptions = @{
    Path = $resolvedPath
    Force = $true
    File = $true
    Directory = $true
}
if($Recurse) {
    $searchOptions["Recurse"] = $true
}

$items = Get-ChildItem @searchOptions | Where-Object { Is-ReparsePointFile $_ -and Matches-Type $_ }

if(-not $items) {
    Write-Host "Nenhum link simbólico/junction encontrado em $resolvedPath."
    Write-Host "concluído."
    return
}

$results = foreach($item in $items) {
    $linkType = $null
    $target = $null
    try {
        $linkType = $item.LinkType
    } catch {
        $linkType = "Desconhecido"
    }
    try {
        $target = $item.Target
        if($target -is [System.Array]) {
            $target = $target -join "; "
        }
    } catch {
        $target = "<indisponível>"
    }
    [pscustomobject]@{
        Path      = $item.FullName
        Type      = if($item.PSIsContainer) { "Directory" } else { "File" }
        LinkType  = $linkType
        Target    = $target
        Exists    = if($target -and (Test-Path $target)) { "Yes" } else { "No" }
    }
}

$results | Format-Table -AutoSize
Write-Host "concluído."

if($Summary) {
    $countDir = ($results | Where-Object { $_.Type -eq "Directory" }).Count
    $countFile = ($results | Where-Object { $_.Type -eq "File" }).Count
    Write-Host ""
    Write-Host "Resumo:"
    Write-Host ("  - Diretórios: {0}" -f $countDir)
    Write-Host ("  - Arquivos..: {0}" -f $countFile)
    Write-Host ("  - Total.....: {0}" -f $results.Count)
    $missing = $results | Where-Object { $_.Exists -eq "No" }
    if($missing) {
        Write-Host ("  - Atenção: {0} link(s) com alvo inexistente." -f $missing.Count)
    }
}
