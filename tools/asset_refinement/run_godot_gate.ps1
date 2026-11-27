param(
    [Parameter(Mandatory)][string]$Godot,
    [Parameter(Mandatory)][string]$Python,
    [string]$VisualRoot = 'Z:\NightGrid-Afterhours\Visual'
)

$ErrorActionPreference = 'Stop'
$godotPath = (Resolve-Path -LiteralPath $Godot).Path
$pythonPath = (Resolve-Path -LiteralPath $Python).Path
$visualPath = (Resolve-Path -LiteralPath $VisualRoot).Path
$raw = Join-Path $visualPath 'visual-001'
$refined = Join-Path $visualPath 'refined-001'
$report = Join-Path $refined 'godot-1024.json'
& $pythonPath -u (Join-Path $PSScriptRoot 'godot_gate.py')  --raw $raw --refined $refined --size 1024 --godot $godotPath --output $report
exit $LASTEXITCODE
