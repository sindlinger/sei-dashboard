[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [switch]$Recurse
)

$ErrorActionPreference = "Stop"

function Resolve-TargetDir([string]$inputPath) {
    if(-not (Test-Path $inputPath)) {
        throw "Caminho '$inputPath' nao encontrado."
    }
    return (Resolve-Path -LiteralPath $inputPath).ProviderPath
}

function Is-Link([System.IO.FileSystemInfo]$item) {
    return (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
}

$targetPath = Resolve-TargetDir $Path

$searchParams = @{
    Path  = $targetPath
    Force = $true
    File  = $true
    Directory = $true
}

if($Recurse) {
    $searchParams["Recurse"] = $true
}

$items = Get-ChildItem @searchParams | Where-Object { Is-Link $_ }

if(-not $items) {
    Write-Host "[remove-links] Nenhum link encontrado em $targetPath."
    return
}

foreach($item in $items) {
    Write-Host ("[remove-links] removendo {0}" -f $item.FullName)
    Remove-Item -LiteralPath $item.FullName -Force
}

Write-Host "[remove-links] concluido."
