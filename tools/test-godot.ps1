param([Parameter(Mandatory = $true)][string]$GodotPath, [switch]$AllTracks)
$ErrorActionPreference = 'Stop'
$nativeProject = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\godot'))
$outputDirectory = Join-Path $nativeProject 'test-output'
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
function Invoke-RaceTest([string]$Script, [string]$Name, [string]$Success, [string[]]$ExtraArgs = @()) {
    $log = Join-Path $outputDirectory ($Name + '.log')
    $arguments = @('--headless', '--path', ('"' + $nativeProject + '"'), '--fixed-fps', '60', '--script', $Script, '--log-file', ('"' + $log + '"'), '--', '--test-mode') + $ExtraArgs
    $run = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WindowStyle Hidden -PassThru
    if (-not $run.WaitForExit(120000)) { $run.Kill(); throw "Timeout: $Name" }
    $content = Get-Content -LiteralPath $log -Raw
    if ($run.ExitCode -ne 0 -or $content -match 'SCRIPT ERROR|FAIL:' -or $content -notmatch $Success) { throw "Test failed: $Name. See $log" }
    Write-Output ($content -split '\r?\n' | Where-Object { $_ -match 'RESULT:|DRIVE PASS:' })
}
$import = Start-Process -FilePath $GodotPath -ArgumentList @('--headless', '--editor', '--import', '--path', ('"' + $nativeProject + '"'), '--quit', '--log-file', ('"' + (Join-Path $outputDirectory 'import.log') + '"')) -WindowStyle Hidden -PassThru -Wait
if ($import.ExitCode -ne 0) { throw 'Import failed' }
Invoke-RaceTest 'res://tests/test_race.gd' 'regression' 'RESULT: 28 checks, 0 failures'
$tracks = @('monza')
if ($AllTracks) { $tracks = @('monza', 'spa', 'silverstone', 'nurburgring', 'suzuka', 'imola', 'redbull', 'bathurst', 'laguna') }
foreach ($track in $tracks) {
    Invoke-RaceTest 'res://tests/drive_lap.gd' ('drive-' + $track) ('DRIVE PASS: track=' + $track) @('--track=' + $track)
}
