param([string]$BlenderPath='D:\ruanjian\Blender 4.5\blender.exe')
$ErrorActionPreference='Stop'
$logs=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\art\build_logs'))
New-Item -ItemType Directory -Path $logs -Force | Out-Null
foreach ($variant in @('v8','r6','v6')) {
    $source=Join-Path $PSScriptRoot 'blender\build_clubsport_gt.py'
    $p=Start-Process -FilePath $BlenderPath -ArgumentList @('--background','--factory-startup','--python',('"'+$source+'"'),'--',('--variant='+$variant)) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $logs ($variant+'.log')) -RedirectStandardError (Join-Path $logs ($variant+'-error.log'))
    if($p.ExitCode -ne 0){throw ('Failed: '+$variant)}
    Write-Output ('CAR READY: '+$variant)
}
