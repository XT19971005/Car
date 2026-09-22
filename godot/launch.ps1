param([string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
if (-not $GodotPath) {
    $candidate = Get-Command godot -ErrorAction SilentlyContinue
    if ($candidate) { $GodotPath = $candidate.Source }
    else { $GodotPath = 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' }
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Godot executable not found. Run launch.ps1 -GodotPath <your Godot executable>.' }
# First launch on a clean checkout imports embedded model assets before running.
$nativeArguments = @('--headless', '--editor', '--import', '--path', ('"' + $PSScriptRoot + '"'), '--quit')
$import = Start-Process -FilePath $GodotPath -ArgumentList $nativeArguments -WindowStyle Hidden -PassThru -Wait
if ($import.ExitCode -ne 0) { throw 'Godot asset import failed. Open project.godot to inspect the error.' }
Start-Process -FilePath $GodotPath -ArgumentList @('--path', ('"' + $PSScriptRoot + '"'))
