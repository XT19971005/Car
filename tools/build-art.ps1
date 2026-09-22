param([string]$BlenderPath = 'D:\ruanjian\Blender 4.5\blender.exe')
$ErrorActionPreference = 'Stop'
$artRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\art'))
$artLogDirectory = Join-Path $artRoot 'build_logs'
New-Item -ItemType Directory -Path $artLogDirectory -Force | Out-Null
foreach ($scriptName in @('build_circuit_assets')) {
    $scriptPath = Join-Path $PSScriptRoot ('blender\' + $scriptName + '.py')
    $run = Start-Process -FilePath $BlenderPath -ArgumentList @('--background', '--factory-startup', '--python', ('"' + $scriptPath + '"')) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $artLogDirectory ($scriptName + '.log')) -RedirectStandardError (Join-Path $artLogDirectory ($scriptName + '-error.log'))
    if ($run.ExitCode -ne 0) { throw "Blender build failed: $scriptName" }
    Write-Output "Built: $scriptName"
}
& (Join-Path $PSScriptRoot 'build-cars.ps1') -BlenderPath $BlenderPath
