Start-Process PowerShell -Verb RunAs -ArgumentList @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-WorkingDirectory', 'C:\Users\pichau\AppData\Roaming\MetaQuotes\Terminal\3CA1B4AB7DFED5C81B1C7F1007926D06\MQL5\WaveSpecGPU'
)
