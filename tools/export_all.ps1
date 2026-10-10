# Exports every .blend in source_art\characters and source_art\props to .glb
# inside the Godot project (models\characters, models\props).
#
#   powershell -ExecutionPolicy Bypass -File tools\export_all.ps1            # everything
#   powershell -ExecutionPolicy Bypass -File tools\export_all.ps1 hippo_girl # just one model
#
# Godot picks the new .glb files up automatically the next time the editor is focused.

param([string]$Only = "")

$ErrorActionPreference = "Stop"
$root    = Split-Path $PSScriptRoot -Parent
$blender = "C:\Program Files\Blender 4.5\blender.exe"
$script  = Join-Path $PSScriptRoot "export_glb.py"
$models  = Join-Path $root "Godot Project\my-world\models"

foreach ($category in "characters", "props") {
    $src = Join-Path $root "source_art\$category"
    if (-not (Test-Path $src)) { continue }
    foreach ($blend in Get-ChildItem $src -Filter *.blend) {
        if ($Only -and $blend.BaseName -ne $Only) { continue }
        $glb = Join-Path $models "$category\$($blend.BaseName).glb"
        Write-Host "Exporting $category\$($blend.Name)"
        & $blender -b $blend.FullName --python $script -- $glb | Select-String "EXPORTED|Error" | ForEach-Object { Write-Host "  $($_.Line)" }
        if ($LASTEXITCODE -ne 0) { throw "Blender failed on $($blend.Name)" }
    }
}
