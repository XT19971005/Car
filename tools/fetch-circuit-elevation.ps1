$ErrorActionPreference = 'Stop'
$referenceDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\art\reference_data'))
$geo = Get-Content -LiteralPath (Join-Path $referenceDirectory 'f1-circuits.geojson') -Raw | ConvertFrom-Json
foreach ($circuit in @(@('monza','it-1922'), @('spa','be-1925'), @('silverstone','gb-1948'))) {
    $feature = $geo.features | Where-Object { $_.properties.id -eq $circuit[1] }
    $allResults = @()
    $coordinates = $feature.geometry.coordinates
    for ($offset = 0; $offset -lt $coordinates.Count; $offset += 95) {
        $end = [Math]::Min($coordinates.Count - 1, $offset + 94)
        $locations = ($coordinates[$offset..$end] | ForEach-Object { [string]$_[1] + ',' + [string]$_[0] }) -join '|'
        $response = Invoke-RestMethod -NoProxy -Uri ('https://api.opentopodata.org/v1/srtm30m?locations=' + [Uri]::EscapeDataString($locations))
        if ($response.status -ne 'OK') { throw "Elevation request failed: $($circuit[0])" }
        $allResults += $response.results
        Start-Sleep -Milliseconds 1100
    }
    @{source='Open Topo Data / SRTM30m'; resolution_metres=30; caveat='Terrain elevation, not surveyed road surface'; results=$allResults} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $referenceDirectory ($circuit[0] + '-elevation.json')) -Encoding utf8
    Write-Output ('ELEVATION READY: ' + $circuit[0] + ' ' + $allResults.Count)
}
