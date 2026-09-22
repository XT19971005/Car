$ErrorActionPreference = 'Stop'
$referenceDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\art\reference_data'))
# Official OSM map API: west,south,east,north. Local XML cache, derived data under ODbL.
foreach ($venue in @(@('monza','9.270,45.607,9.305,45.640'),@('spa','5.952,50.425,5.993,50.455'),@('silverstone','-1.041,52.065,-1.000,52.087'))) {
    $target = Join-Path $referenceDirectory ($venue[0] + '-osm.xml')
    Invoke-WebRequest -NoProxy -Uri ('https://api.openstreetmap.org/api/0.6/map?bbox=' + $venue[1]) -OutFile $target
    [xml]$document = Get-Content -LiteralPath $target -Raw
    if (-not $document.osm) { throw ('Invalid OSM download: ' + $venue[0]) }
    Write-Output ('VENUE READY: ' + $venue[0])
}
