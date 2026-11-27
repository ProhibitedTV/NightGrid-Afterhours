param([Parameter(Mandatory)][string]$Source)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$target = Join-Path $repo 'assets\creator_playtest_cast'
$hashes = @{
    'dev.glb' = 'da44fc3cef88d7f55f2837b22b355140536ac19f0530a0779d1257a30d93bdd6'
    'rina.glb' = '74321e1f1184090c50915ef8901d7c2b067f8643d21bb85055166558b4b1b08e'
    'dana.glb' = '642073bc5d603e0dff9b99c5f6e0d2a5f8565bb995bea7636f1568cdafd70d84'
    'jetson.glb' = '4f7878f077863584eb6ff9229cb8175d427db8298b45987184a1bcc85fdf8d36'
}
foreach ($name in $hashes.Keys) {
    if ((Get-FileHash -LiteralPath (Join-Path $Source $name)).Hash -ne $hashes[$name]) {
        throw "Candidate checksum mismatch: $name"
    }
}
# Only the pinned four files may be included by the export wildcard.
$allowed = @($hashes.Keys | ForEach-Object { $_ + '.bin' })
if (Test-Path -LiteralPath $target) {
    foreach ($item in (Get-ChildItem -LiteralPath $target -Force -File -Recurse)) {
        if ($item.Extension -ieq '.bin' -and ($item.DirectoryName -ne $target -or $item.Name -cnotin $allowed)) {
            throw "Unexpected private payload; preserve it outside the staging folder: $($item.FullName)"
        }
    }
}
# Validate the entire destination before copying anything. Never replace a
# prior candidate or stage a mixed set because a later destination is stale.
foreach ($name in ($hashes.Keys | Sort-Object)) {
    $output = Join-Path $target ($name + ".bin")
    if (Test-Path -LiteralPath $output) {
        if (-not (Test-Path -LiteralPath $output -PathType Leaf) -or
            (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash -ne $hashes[$name]) {
            throw "Existing staged candidate differs; preserve it and use a clean worktree: $name"
        }
    }
}
New-Item -ItemType Directory -Path $target -Force | Out-Null
foreach ($name in $hashes.Keys) {
    $output = Join-Path $target ($name + ".bin")
    if (-not (Test-Path -LiteralPath $output)) {
        [System.IO.File]::Copy((Join-Path (Resolve-Path -LiteralPath $Source).Path $name), $output, $false)
    }
    if ((Get-FileHash -LiteralPath $output).Hash -ne $hashes[$name]) {
        throw "Staged candidate checksum mismatch: $name"
    }
}

Write-Output 'CREATOR_CAST_STAGE PASS: all four exact candidate hashes verified'
