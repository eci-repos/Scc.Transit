$ErrorActionPreference = 'Stop'

$outputPath = Join-Path $PSScriptRoot '..\data\scc_transit_poc_2024_2026.csv'
$monthlyLayer = 'https://gis.vta.org/gis/rest/services/Hosted/Ridership_by_Route_Cumulative_Monthly2025/FeatureServer/0'
$yearlyLayer = 'https://gis.vta.org/gis/rest/services/Hosted/Ridership_by_Route_Cumulative_Yearly2025/FeatureServer/0'
$monthlyQuery = "$monthlyLayer/query"
$yearlyQuery = "$yearlyLayer/query"

$rows = [System.Collections.Generic.List[object]]::new()

function Add-TransitRow {
    param([hashtable]$Values)
    $rows.Add([pscustomobject][ordered]@{
        record_type  = $Values.record_type
        year         = $Values.year
        period_start = $Values.period_start
        period_end   = $Values.period_end
        operator     = $Values.operator
        service      = $Values.service
        route_id     = $Values.route_id
        line_type    = $Values.line_type
        day_type     = $Values.day_type
        metric       = $Values.metric
        metric_value = $Values.metric_value
        unit         = $Values.unit
        data_status  = $Values.data_status
        source_url   = $Values.source_url
        source_id    = $Values.source_id
        notes        = $Values.notes
    })
}

function Convert-EpochMillisecondsToDate {
    param([long]$Milliseconds)
    return [DateTimeOffset]::FromUnixTimeMilliseconds($Milliseconds).UtcDateTime.ToString('yyyy-MM-dd')
}

function Get-MonthEnd {
    param([datetime]$Date)
    return $Date.AddMonths(1).AddDays(-1).ToString('yyyy-MM-dd')
}

function Get-ArcGisRows {
    param(
        [string]$QueryUrl,
        [string]$Where,
        [string]$OrderBy = 'objectid ASC'
    )

    $result = [System.Collections.Generic.List[object]]::new()
    $offset = 0
    do {
        $query = "${QueryUrl}?where=$([uri]::EscapeDataString($Where))&outFields=*&returnGeometry=false&resultRecordCount=2000&resultOffset=$offset&orderByFields=$([uri]::EscapeDataString($OrderBy))&f=json"
        $payload = Invoke-RestMethod -Uri $query -Method Get
        if ($null -ne $payload.error) {
            throw "ArcGIS query failed: $($payload.error.message)"
        }
        foreach ($feature in @($payload.features)) {
            $result.Add($feature.attributes)
        }
        $pageCount = @($payload.features).Count
        $offset += $pageCount
    } while ($pageCount -eq 2000 -and $offset -lt 1000000)

    return $result
}

# VTA route/month/day-type records currently published by the ArcGIS layer.
foreach ($year in 2024, 2025) {
    $nextYear = $year + 1
    $where = "period >= DATE '$year-01-01' AND period < DATE '$nextYear-01-01'"
    foreach ($item in @(Get-ArcGisRows -QueryUrl $monthlyQuery -Where $where -OrderBy 'period ASC, objectid ASC')) {
        $periodDate = [DateTimeOffset]::FromUnixTimeMilliseconds([int64]$item.period).UtcDateTime.Date
        Add-TransitRow @{
            record_type  = 'route_month_daytype'
            year         = $year
            period_start = $periodDate.ToString('yyyy-MM-dd')
            period_end   = Get-MonthEnd $periodDate
            operator     = 'VTA'
            service      = 'VTA fixed-route transit'
            route_id     = [string]$item.routes
            line_type    = [string]$item.linetype
            day_type     = [string]$item.dayofweek
            metric       = 'boardings'
            metric_value = $item.boardings
            unit         = 'boardings'
            data_status  = 'published_historical'
            source_url   = "$monthlyLayer"
            source_id    = 'vta_arcgis_ridership_monthly_2025'
            notes        = 'VTA ArcGIS published value; preserve as supplied for POC exploration and validate aggregation semantics with VTA before using as a headline KPI.'
        }
    }
}

# VTA route/year/day-type records currently published by the ArcGIS layer.
foreach ($year in 2024, 2025) {
    $where = "yearly=$year"
    foreach ($item in @(Get-ArcGisRows -QueryUrl $yearlyQuery -Where $where -OrderBy 'objectid ASC')) {
        Add-TransitRow @{
            record_type  = 'route_year_daytype'
            year         = $year
            period_start = "$year-01-01"
            period_end   = "$year-12-31"
            operator     = 'VTA'
            service      = 'VTA fixed-route transit'
            route_id     = [string]$item.routes
            line_type    = [string]$item.linetype
            day_type     = [string]$item.dayofweek
            metric       = 'boardings'
            metric_value = $item.boardings
            unit         = 'boardings'
            data_status  = 'published_historical'
            source_url   = "$yearlyLayer"
            source_id    = 'vta_arcgis_ridership_yearly_2025'
            notes        = 'VTA ArcGIS published route/year/day-type value; preserve as supplied for POC exploration and validate aggregation semantics with VTA before using as a headline KPI.'
        }
    }
}

# System-level ridership reported by VTA. 2026 is intentionally partial.
$annualRidership = @(
    @{ year = 2024; start = '2024-01-01'; end = '2024-12-31'; status = 'complete'; source = 'https://www.vta.org/media/48736'; sourceId = 'vta_ridership_dec_2025'; note = "Calendar-year 2024 total reported as the prior-year comparison in VTA's December 2025 ridership report."; values = @{ Bus = 23661300; 'Light Rail' = 5016183; System = 28677483 } },
    @{ year = 2025; start = '2025-01-01'; end = '2025-12-31'; status = 'complete'; source = 'https://www.vta.org/media/48736'; sourceId = 'vta_ridership_dec_2025'; note = "Calendar-year 2025 total reported in VTA's December 2025 ridership report."; values = @{ Bus = 22430585; 'Light Rail' = 4485965; System = 26916550 } },
    @{ year = 2026; start = '2026-01-01'; end = '2026-01-31'; status = 'partial_ytd'; source = 'https://www.vta.org/media/48896'; sourceId = 'vta_ridership_jan_2026'; note = 'January 2026 only; do not treat as a full-year total.'; values = @{ Bus = 1898808; 'Light Rail' = 381529; System = 2280337 } }
)
foreach ($period in $annualRidership) {
    foreach ($serviceName in 'Bus', 'Light Rail', 'System') {
        Add-TransitRow @{
            record_type  = 'system_ridership'
            year         = $period.year
            period_start = $period.start
            period_end   = $period.end
            operator     = 'VTA'
            service      = $serviceName
            route_id     = 'SYSTEM'
            line_type    = $serviceName
            day_type     = 'All'
            metric       = 'boardings'
            metric_value = $period.values[$serviceName]
            unit         = 'boardings'
            data_status  = $period.status
            source_url   = $period.source
            source_id    = $period.sourceId
            notes        = $period.note
        }
    }
}

# Historical/current GTFS snapshot metadata available through Transitland.
$gtfsSnapshots = @(
    @{ year = 2024; start = '2024-01-15'; end = '2024-04-28'; routes = 73; stops = 3297; sha1 = '8d6d3e7b7268ab1eacb417a42a15ac7b20da00c4'; source = 'https://www.transit.land/feeds/f-9q9-vta/versions/8d6d3e7b7268ab1eacb417a42a15ac7b20da00c4'; status = 'snapshot'; note = 'Archived VTA GTFS snapshot; service dates are the feed validity window.' },
    @{ year = 2024; start = '2024-08-12'; end = '2024-10-27'; routes = 84; stops = 3386; sha1 = '4b5d5568516da4a90113f09f994505cc8dee286a'; source = 'https://www.transit.land/feeds/f-9q9-vta/versions/4b5d5568516da4a90113f09f994505cc8dee286a'; status = 'snapshot'; note = 'Archived VTA GTFS snapshot; service dates are the feed validity window.' },
    @{ year = 2025; start = '2025-01-13'; end = '2025-08-10'; routes = 82; stops = 3340; sha1 = 'dab0b673c7011971478107c6849c061ac40d3b3f'; source = 'https://www.transit.land/feeds/f-9q9-vta/versions/dab0b673c7011971478107c6849c061ac40d3b3f'; status = 'snapshot'; note = 'Archived VTA GTFS snapshot; service dates are the feed validity window.' },
    @{ year = 2026; start = '2026-08-10'; end = '2026-10-25'; routes = 72; stops = 3344; sha1 = '1b963536c23260510bf4c586002d2643417f422c'; source = 'https://www.transit.land/feeds/f-9q9-vta/versions/1b963536c23260510bf4c586002d2643417f422c'; status = 'current_snapshot'; note = 'Current 2026 VTA GTFS snapshot listed by Transitland; service dates are the feed validity window, not a full calendar year.' }
)
foreach ($snapshot in $gtfsSnapshots) {
    foreach ($metricName in 'route_count', 'stop_count') {
        $value = if ($metricName -eq 'route_count') { $snapshot.routes } else { $snapshot.stops }
        Add-TransitRow @{
            record_type  = 'gtfs_snapshot'
            year         = $snapshot.year
            period_start = $snapshot.start
            period_end   = $snapshot.end
            operator     = 'VTA'
            service      = 'VTA GTFS'
            route_id     = ''
            line_type    = ''
            day_type     = ''
            metric       = $metricName
            metric_value = $value
            unit         = 'count'
            data_status  = $snapshot.status
            source_url   = $snapshot.source
            source_id    = "transitland_vta_gtfs_$($snapshot.sha1)"
            notes        = "$($snapshot.note) GTFS version SHA1: $($snapshot.sha1)."
        }
    }
}

# Source catalog for live/refreshable POC integrations.
$sources = @(
    @{ service = 'VTA GTFS static feed'; url = 'https://gtfs.vta.org/gtfs_vta.zip'; id = 'vta_gtfs_static'; note = 'Static routes, stops, trips, calendars, shapes, and fares; current feed.' },
    @{ service = 'VTA GTFS-RT trip updates'; url = 'https://api-vta.vta.org/gtfsrt/tripUpdates.pb'; id = 'vta_gtfsrt_trip_updates'; note = 'Live trip updates in GTFS-Realtime protobuf format.' },
    @{ service = 'VTA GTFS-RT vehicle positions'; url = 'https://api-vta.vta.org/gtfsrt/vehiclePositions.pb'; id = 'vta_gtfsrt_vehicle_positions'; note = 'Live vehicle positions in GTFS-Realtime protobuf format.' },
    @{ service = 'VTA GTFS-RT alerts'; url = 'https://api-vta.vta.org/gtfsrt/alerts.pb'; id = 'vta_gtfsrt_alerts'; note = 'Live service alerts in GTFS-Realtime protobuf format.' },
    @{ service = 'VTA route directory'; url = 'https://www.vta.org/go/routes'; id = 'vta_routes_directory'; note = 'Human-readable VTA route directory.' },
    @{ service = 'VTA ridership monthly ArcGIS layer'; url = $monthlyLayer; id = 'vta_arcgis_ridership_monthly_2025'; note = 'Published route/month/day-type ridership layer; currently reaches 2025-08.' },
    @{ service = 'VTA ridership yearly ArcGIS layer'; url = $yearlyLayer; id = 'vta_arcgis_ridership_yearly_2025'; note = 'Published route/year/day-type ridership layer; current published year is 2025.' },
    @{ service = 'VTA ACCESS paratransit'; url = 'https://www.vta.org/go/paratransit/access'; id = 'vta_access'; note = 'Related accessible transportation service for eligible riders; add service-level data when an official feed is available.' },
    @{ service = 'VTA GTFS archive metadata'; url = 'https://www.transit.land/feeds/f-9q9-vta'; id = 'transitland_vta_feed'; note = 'Historical/current VTA GTFS feed-version metadata.' }
)
foreach ($source in $sources) {
    Add-TransitRow @{
        record_type  = 'source_catalog'
        year         = 2026
        period_start = ''
        period_end   = ''
        operator     = 'VTA'
        service      = $source.service
        route_id     = ''
        line_type    = ''
        day_type     = ''
        metric       = 'source_available'
        metric_value = 1
        unit         = 'boolean'
        data_status  = 'available'
        source_url   = $source.url
        source_id    = $source.id
        notes        = $source.note
    }
}

$rows | Sort-Object record_type, year, period_start, service, route_id, day_type | Export-Csv -Path $outputPath -NoTypeInformation -Encoding utf8
Write-Output "Wrote $($rows.Count) rows to $([System.IO.Path]::GetFullPath($outputPath))"
