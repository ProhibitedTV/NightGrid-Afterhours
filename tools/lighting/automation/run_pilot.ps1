param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [Parameter(Mandatory=$true)][string]$Project,
    [int]$TimeoutSeconds=1200
)
$ErrorActionPreference = 'Stop'
$Godot = (Resolve-Path $Godot).Path
$Project = (Resolve-Path $Project).Path
if (!(Test-Path (Join-Path $Project 'nightgrid_bake_pilot.marker'))) { throw 'Not an isolated pilot' }
if (Test-Path (Join-Path $Project 'bake-result.json')) { throw 'Use a fresh pilot directory' }
$version = & $Godot --version
if ($version -notmatch '^4\.7\.2([.\-+]|$)') { throw "Godot 4.7.2 required: $version" }
function Assert-Resources {
    $line = @(& nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
    if ($LASTEXITCODE -ne 0 -or $line.Count -ne 1) { throw 'Missing single GPU temperature telemetry' }
    $temp = 0.0
    if (![double]::TryParse($line[0].Trim(), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$temp) -or $temp -le 0 -or $temp -ge 85) { throw "Unsafe GPU temperature: $line" }
    foreach ($drive in @('C','Z')) {
        $d = Get-PSDrive -Name $drive
        $reserve = if ($drive -eq 'C') { 25GB } else { 10GB }
        if ($null -eq $d.Free -or $d.Free -lt $reserve) { throw "Drive $drive reserve breached" }
    }
}
function Run-Guarded([string]$Name,[string]$Arguments) {
    Assert-Resources
    $proc = Start-Process -FilePath $Godot -ArgumentList $Arguments -PassThru -RedirectStandardOutput (Join-Path $Project "$Name.stdout.log") -RedirectStandardError (Join-Path $Project "$Name.stderr.log")
    try {
        # Retain the OS handle before polling; Windows PowerShell can otherwise
        # return a null ExitCode after a redirected process terminates.
        $null = $proc.Handle
        $clock = [Diagnostics.Stopwatch]::StartNew()
        while (!$proc.HasExited) {
            if ($clock.Elapsed.TotalSeconds -gt $TimeoutSeconds) { throw "$Name timeout" }
            Assert-Resources
            Start-Sleep -Seconds 5
            $proc.Refresh()
        }
        $proc.WaitForExit()
        $code = $proc.ExitCode
        if ($null -eq $code) { throw "$Name exited but its exit code is unavailable; inspect logs" }
        if ($code -ne 0) { throw "$Name failed: $code" }
        Write-Host "$Name completed (exit $code)"
    } finally {
        if (!$proc.HasExited) { Stop-Process -Id $proc.Id -Force; $proc.WaitForExit() }
        $proc.Dispose()
    }
}
# Import dependencies before activating the editor-only experimental plugin.
$cfg = Join-Path $Project 'project.godot'
$enabled = Get-Content -Raw $cfg
$disabled = $enabled.Replace('enabled=PackedStringArray("res://addons/nightgrid_bake/plugin.cfg")','enabled=PackedStringArray()')
$disabled | Set-Content -Encoding ASCII $cfg
Run-Guarded 'initial-import' "--headless --editor --path `"$Project`" --import"
$enabled | Set-Content -Encoding ASCII $cfg
# Native editor, not headless bake. The pilot plugin saves and exits.
Run-Guarded 'bake' "--editor --path `"$Project`" --rendering-method forward_plus --rendering-driver vulkan --language en"
$result = Get-Content -Raw (Join-Path $Project 'bake-result.json') | ConvertFrom-Json
if ($result.status -ne 'candidate-only' -or $result.users -lt 1 -or $result.renderer -ne 'forward_plus') { throw 'Invalid bake result' }
# Disable the experimental editor plugin before independently importing and checking.
$cfg = Join-Path $Project 'project.godot'
(Get-Content -Raw $cfg).Replace('enabled=PackedStringArray("res://addons/nightgrid_bake/plugin.cfg")','enabled=PackedStringArray()') | Set-Content -Encoding ASCII $cfg
Run-Guarded 'import' "--headless --editor --path `"$Project`" --import"
Run-Guarded 'validate' "--headless --path `"$Project`" --script res://tools/lighting/validate_synaxis_reception.gd"
if (!(Select-String -Quiet -SimpleMatch 'SYNAXIS_RECEPTION_LIGHTMAP_INPUT PASS' (Join-Path $Project 'validate.stdout.log'))) { throw 'Missing independent validation marker' }
$evidence = Join-Path $Project 'evidence'
Run-Guarded 'capture' "--path `"$Project`" --fullscreen --resolution 1920x1080 --rendering-method forward_plus --rendering-driver vulkan --script res://tools/lighting/capture_synaxis_reception_bake.gd -- `"$evidence`""
if (!(Test-Path (Join-Path $evidence 'pilot.json'))) { throw 'Native matched image/probe comparison did not pass' }
$atlas = @(Get-ChildItem (Join-Path $Project 'tools/lighting') -File | Where-Object { $_.Extension -in '.exr','.lmbake','.tscn' })
if (!($atlas | Where-Object Extension -eq '.exr') -or !($atlas | Where-Object Extension -eq '.lmbake')) { throw 'Missing new atlas files' }
$records = @($atlas | ForEach-Object { @{file=$_.Name; bytes=$_.Length; sha256=(Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()} })
@{status='candidate-only';engine="$version";result=$result;outputs=$records;visual_review='pending'} | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 (Join-Path $Project 'validated-bake.json')
Write-Host "Native bake validated; inspect $Project"
