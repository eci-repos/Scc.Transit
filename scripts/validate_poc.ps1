param(
    [string]$Server = 'localhost',
    [string]$Database = 'SccTransitPoc'
)

$ErrorActionPreference = 'Stop'
$sqlcmd = (Get-Command sqlcmd -ErrorAction Stop).Source
$query = @'
SELECT 'staging.RawTransitData' AS ObjectName, COUNT_BIG(*) AS [RowCount] FROM staging.RawTransitData
UNION ALL SELECT 'warehouse.FactTransitMetric', COUNT_BIG(*) FROM warehouse.FactTransitMetric
UNION ALL SELECT 'warehouse.FactGtfsSnapshot', COUNT_BIG(*) FROM warehouse.FactGtfsSnapshot
UNION ALL SELECT 'mart.vw_RidershipSummary', COUNT_BIG(*) FROM mart.vw_RidershipSummary;
SELECT CalendarYear, ServiceName, SUM(MetricValue) AS Boardings
FROM mart.vw_RidershipSummary
WHERE RecordType = 'system_ridership' AND MetricName = 'boardings'
GROUP BY CalendarYear, ServiceName
ORDER BY CalendarYear, ServiceName;
'@

& $sqlcmd -S $Server -E -d $Database -b -W -s ' | ' -Q $query
if ($LASTEXITCODE -ne 0) { throw "Validation failed with exit code $LASTEXITCODE." }
