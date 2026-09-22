$ErrorActionPreference = 'Stop'
$referenceDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\art\reference_data'))
$geo = Get-Content -LiteralPath (Join-Path $referenceDirectory 'f1-circuits.geojson') -Raw | ConvertFrom-Json
foreach ($circuit in @(@('monza','it-1922'), @('spa','be-1925'), @('silverstone','gb-1948'))) {
    $feature = $geo.features | Where-Object { $_.properties.id -eq $circuit[1] }
    $coordinates = $feature.geometry.coordinates
    $longitudes = $coordinates | ForEach-Object { $_[0] }
    $latitudes = $coordinates | ForEach-Object { $_[1] }
    $lo = ($longitudes | Measure-Object -Minimum).Minimum - .004
    $hi = ($longitudes | Measure-Object -Maximum).Maximum + .004
    $bottom = ($latitudes | Measure-Object -Minimum).Minimum - .003
    $top = ($latitudes | Measure-Object -Maximum).Maximum + .003
    $locations = @()
    for ($z=0; $z -lt 20; $z++) { for ($x=0; $x -lt 20; $x++) { $locations += ('{0:F6},{1:F6}' -f ($bottom+($top-$bottom)*$z/19), ($lo+($hi-$lo)*$x/19)) } }
    $allResults = @()
    for ($offset=0; $offset -lt 400; $offset+=95) {
        $end = [Math]::Min(399, $offset+94)
        $response = Invoke-RestMethod -NoProxy -Uri ('https://api.opentopodata.org/v1/srtm30m?locations=' + [Uri]::EscapeDataString(($locations[$offset..$end] -join '|')))
        if ($response.status -ne 'OK') { throw 'Terrain request failed' }
        $allResults += $response.results
        Start-Sleep -Milliseconds 1100
    }
    @{source='Open Topo Data / SRTM30m'; resolution_metres=30; grid_size=20; results=$allResults} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $referenceDirectory ($circuit[0]+'-terrain.json')) -Encoding utf8
    Write-Output ('TERRAIN READY: '+$circuit[0])
}
