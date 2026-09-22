param([string[]]$CarKeys=@('v8'), [string]$GodotPath='D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe')
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\godot'))
$tracks=@('monza','spa','silverstone','nurburgring','suzuka','imola','redbull','bathurst','laguna')
$failed=@()
foreach($carKey in $CarKeys){
for($offset=0;$offset -lt $tracks.Count;$offset+=3){
    $runs=@()
    foreach($track in $tracks[$offset..([Math]::Min($offset+2,$tracks.Count-1))]){
        $log=Join-Path $project ('test-output/static-drive-'+$track+'-'+$carKey+'.log')
        $process=Start-Process -FilePath $GodotPath -ArgumentList @('--headless','--path',('"'+$project+'"'),'--fixed-fps','60','--script','res://tests/drive_lap.gd','--log-file',('"'+$log+'"'),'--','--test-mode',('--track='+$track),('--car='+$carKey)) -WindowStyle Hidden -PassThru
        $runs+=@{Process=$process;Log=$log;Track=$track}
    }
    foreach($run in $runs){
        if(-not $run.Process.WaitForExit(180000)){$run.Process.Kill();$failed+=$run.Track;Write-Output ('TIMEOUT '+$run.Track);continue}
        $content=Get-Content -LiteralPath $run.Log -Raw
        $content -split '\r?\n' | Where-Object {$_ -match 'DRIVE PASS:|DRIVE FAIL:|STALL|COLLISION'}
        if($run.Process.ExitCode -ne 0 -or $content -notmatch 'DRIVE PASS:' -or $content -match 'SCRIPT ERROR|DRIVE FAIL:'){$failed+=$run.Track}
    }
}
if($failed.Count){throw ('Failed circuits: '+($failed -join ', '))}
}
Write-Output 'ALL REQUESTED CIRCUIT / CAR COMBINATIONS PASS'
