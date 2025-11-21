param()

$metaEditor = "C:\Program Files\MetaTrader 5\metaeditor64.exe"
if(-not (Test-Path $metaEditor)) {
    throw "metaeditor64.exe não encontrado em $metaEditor"
}

$devIndicators = "C:\Users\pichau\AppData\Roaming\MetaQuotes\Terminal\3CA1B4AB7DFED5C81B1C7F1007926D06\MQL5\WaveSpecGPU\Dev\Indicators"
if(-not (Test-Path $devIndicators)) {
    throw "Pasta de indicadores não encontrada: $devIndicators"
}

Get-ChildItem -Path $devIndicators -Filter '*.mq5' -Recurse | ForEach-Object {
    $file = $_.FullName
    Write-Host "[compile] $file"
    & $metaEditor /compile:"$file" /log
}
