param(
    [string]$ProjectRoot = (Join-Path $PSScriptRoot '..')
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path $ProjectRoot).Path
$ProjectName = 'SccTransitPoc'
$ReportFolder = Join-Path $ProjectRoot "powerbi\$ProjectName.Report"
$ModelFolder = Join-Path $ProjectRoot "powerbi\$ProjectName.SemanticModel"
$DefinitionFolder = Join-Path $ReportFolder 'definition'
$PagesFolder = Join-Path $DefinitionFolder 'pages'
$ModelDefinitionFolder = Join-Path $ModelFolder 'definition'
$ThemeSource = Join-Path ([System.IO.Path]::GetTempPath()) 'powerbi-poc-ref-641ff02edf34487b95e6e1dd04618f10\reports\demo\Demo.Report\StaticResources\SharedResources\BaseThemes\CY26SU02.json'

function Ensure-Directory([string]$Path) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Write-Utf8([string]$Path, [string]$Content) {
    $parent = Split-Path -Parent $Path
    Ensure-Directory $parent
    Set-Content -LiteralPath $Path -Value $Content -Encoding utf8
}

function Write-Json([string]$Path, $Object) {
    Write-Utf8 $Path ($Object | ConvertTo-Json -Depth 50)
}

function Sql-TableTmdl([string]$TableName, [string]$ViewName, [array]$Columns, [array]$Measures = @(), [string]$SchemaName = 'mart') {
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("table $TableName")
    $lines.Add('')
    foreach ($column in $Columns) {
        $lines.Add("`tcolumn $($column.Name)")
        $lines.Add("`t`tdataType: $($column.Type)")
        $lines.Add("`t`tsourceColumn: $($column.Name)")
        $lines.Add('')
    }
    foreach ($measure in $Measures) {
        $lines.Add("`tmeasure '$($measure.Name)' = $($measure.Expression)")
        $lines.Add('')
    }
    $lines.Add("`tpartition '$TableName' = m")
    $lines.Add("`t`tmode: import")
    $lines.Add("`t`tsource =")
    $lines.Add("`t`t`tlet")
    $lines.Add("`t`t`t`tSource = Sql.Database(Server, Database),")
    $lines.Add("`t`t`t`tNavigation = Source{[Schema=""$SchemaName"",Item=""$ViewName""]}[Data]")
    $lines.Add("`t`t`t`tin")
    $lines.Add("`t`t`t`tNavigation")
    return ($lines -join [Environment]::NewLine)
}

Ensure-Directory (Join-Path $ProjectRoot 'powerbi')
Ensure-Directory $ReportFolder
Ensure-Directory $ModelFolder
Ensure-Directory $ModelDefinitionFolder
Ensure-Directory (Join-Path $ReportFolder 'definition')
Ensure-Directory (Join-Path $ReportFolder 'StaticResources\SharedResources\BaseThemes')

# Remove Power BI-generated metadata from prior Desktop sessions so a rebuild is deterministic.
foreach ($generated in (Get-ChildItem -LiteralPath (Join-Path $ModelDefinitionFolder 'tables') -Filter 'LocalDateTable_*.tmdl' -ErrorAction SilentlyContinue)) {
    Remove-Item -LiteralPath $generated.FullName -Force
}
foreach ($generated in (Get-ChildItem -LiteralPath (Join-Path $ModelDefinitionFolder 'tables') -Filter 'DateTableTemplate_*.tmdl' -ErrorAction SilentlyContinue)) {
    Remove-Item -LiteralPath $generated.FullName -Force
}
foreach ($generatedPath in @(
    (Join-Path $ModelDefinitionFolder 'expressions.tmdl'),
    (Join-Path $ModelFolder 'diagramLayout.json')
)) {
    if (Test-Path -LiteralPath $generatedPath) {
        Remove-Item -LiteralPath $generatedPath -Force
    }
}
foreach ($staleVisualPath in @(
    (Join-Path $PagesFolder 'overview\visuals\year-filter'),
    (Join-Path $PagesFolder 'expected-vs-actual\visuals\year-filter'),
    (Join-Path $PagesFolder 'service-detail\visuals\year-filter')
)) {
    if (Test-Path -LiteralPath $staleVisualPath) {
        Remove-Item -LiteralPath $staleVisualPath -Recurse -Force
    }
}
$modelCache = Join-Path $ModelFolder '.pbi\cache.abf'
if (Test-Path -LiteralPath $modelCache) {
    Remove-Item -LiteralPath $modelCache -Force
}

$pbip = [ordered]@{
    '$schema' = 'https://developer.microsoft.com/json-schemas/fabric/pbip/pbipProperties/1.0.0/schema.json'
    version = '1.0'
    artifacts = @(@{ report = @{ path = "$ProjectName.Report" } })
    settings = @{ enableAutoRecovery = $true }
}
Write-Json (Join-Path $ProjectRoot "powerbi\$ProjectName.pbip") $pbip

$pbir = [ordered]@{
    '$schema' = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definitionProperties/2.0.0/schema.json'
    version = '4.0'
    datasetReference = @{ byPath = @{ path = "../$ProjectName.SemanticModel" } }
}
Write-Json (Join-Path $ReportFolder 'definition.pbir') $pbir

$pbism = [ordered]@{
    '$schema' = 'https://developer.microsoft.com/json-schemas/fabric/item/semanticModel/definitionProperties/1.0.0/schema.json'
    version = '4.0'
    settings = @{}
}
Write-Json (Join-Path $ModelFolder 'definition.pbism') $pbism
Write-Json (Join-Path $ModelFolder '.platform') ([ordered]@{
    '$schema'='https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json'
    metadata=@{ type='SemanticModel'; displayName=$ProjectName }
    config=@{ version='2.0'; logicalId=([guid]::NewGuid().ToString()) }
})

$report = [ordered]@{
    '$schema' = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/report/3.2.0/schema.json'
    themeCollection = @{ baseTheme = @{ name = 'CY26SU02'; reportVersionAtImport = @{ visual = '2.6.0'; report = '3.1.0'; page = '2.3.0' }; type = 'SharedResources' } }
    resourcePackages = @(@{ name = 'SharedResources'; type = 'SharedResources'; items = @(@{ name = 'CY26SU02'; path = 'BaseThemes/CY26SU02.json'; type = 'BaseTheme' }) })
    settings = @{ useStylableVisualContainerHeader = $true; exportDataMode = 'AllowSummarized'; defaultDrillFilterOtherVisuals = $true; allowChangeFilterTypes = $true; useEnhancedTooltips = $true; useDefaultAggregateDisplayName = $true }
}
Write-Json (Join-Path $DefinitionFolder 'report.json') $report
Write-Json (Join-Path $ReportFolder '.platform') ([ordered]@{
    '$schema'='https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json'
    metadata=@{ type='Report'; displayName=$ProjectName }
    config=@{ version='2.0'; logicalId=([guid]::NewGuid().ToString()) }
})
Write-Json (Join-Path $DefinitionFolder 'version.json') ([ordered]@{
    '$schema' = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/versionMetadata/1.0.0/schema.json'
    version = '2.0.0'
})

if (Test-Path -LiteralPath $ThemeSource) {
    Copy-Item -LiteralPath $ThemeSource -Destination (Join-Path $ReportFolder 'StaticResources\SharedResources\BaseThemes\CY26SU02.json') -Force
}

$tableDefinitions = @(
    @{ File='Ridership.tmdl'; Name='Ridership'; View='vw_RidershipSummary'; Columns=@(
        @{Name='CalendarYear';Type='int64'}, @{Name='PeriodStartDate';Type='dateTime'}, @{Name='PeriodEndDate';Type='dateTime'},
        @{Name='OperatorName';Type='string'}, @{Name='ServiceName';Type='string'}, @{Name='RouteId';Type='string'},
        @{Name='LineTypeName';Type='string'}, @{Name='DayTypeName';Type='string'}, @{Name='RecordType';Type='string'},
        @{Name='MetricName';Type='string'}, @{Name='MetricValue';Type='double'}, @{Name='UnitName';Type='string'},
        @{Name='DataStatus';Type='string'}
    ); Measures=@(
        @{Name='Total Boardings';Expression='CALCULATE(SUM(''Ridership''[MetricValue]), ''Ridership''[MetricName] = "boardings")'},
        @{Name='Expected Riders (Prior Year)';Expression='CALCULATE([Total Boardings], FILTER(ALL(''Ridership''[CalendarYear]), ''Ridership''[CalendarYear] = MAX(''Ridership''[CalendarYear]) - 1))'},
        @{Name='Variance to Prior Year';Expression='[Total Boardings] - [Expected Riders (Prior Year)]'},
        @{Name='Variance %';Expression='DIVIDE([Variance to Prior Year], [Expected Riders (Prior Year)])'},
        @{Name='Average Metric Value';Expression='AVERAGE(''Ridership''[MetricValue])'}
    )}
    @{ File='Weather.tmdl'; Name='Weather'; View='vw_WeatherDaily'; Columns=@(
        @{Name='ObservationDate';Type='dateTime'}, @{Name='CalendarYear';Type='int64'}, @{Name='StationId';Type='string'},
        @{Name='StationName';Type='string'}, @{Name='WeatherPerceptionCode';Type='string'}, @{Name='WeatherPerception';Type='string'},
        @{Name='ClassPriority';Type='int64'}, @{Name='TemperatureAvgF';Type='double'}, @{Name='TemperatureMinF';Type='double'},
        @{Name='TemperatureMaxF';Type='double'}, @{Name='PrecipitationInches';Type='double'}, @{Name='WindSpeedMph';Type='double'},
        @{Name='VisibilityMiles';Type='double'}, @{Name='WeatherCondition';Type='string'}, @{Name='ClassificationMethod';Type='string'},
        @{Name='Notes';Type='string'}, @{Name='SourceId';Type='string'}, @{Name='SourceUrl';Type='string'}
    ); Measures=@(
        @{Name='Weather Days';Expression='COUNTROWS(Weather)'},
        @{Name='Average Temperature F';Expression='AVERAGE(''Weather''[TemperatureAvgF])'},
        @{Name='Average Precipitation';Expression='AVERAGE(''Weather''[PrecipitationInches])'}
    )}
    @{ File='Stops.tmdl'; Name='Stops'; View='vw_GtfsStops'; Columns=@(
        @{Name='RouteId';Type='string'}, @{Name='StopId';Type='string'}, @{Name='StopCode';Type='string'},
        @{Name='StopName';Type='string'}, @{Name='StopLat';Type='double'}, @{Name='StopLon';Type='double'},
        @{Name='LocationType';Type='int64'}, @{Name='ParentStation';Type='string'}, @{Name='WheelchairBoarding';Type='string'}
    ); Measures=@(
        @{Name='Stop Count';Expression='COUNTROWS(Stops)'}
    )}
    @{ File='TripPerformance.tmdl'; Name='TripPerformance'; View='vw_TripPerformance'; Columns=@(
        @{Name='ObservedAtUtc';Type='dateTime'}, @{Name='TripId';Type='string'}, @{Name='RouteId';Type='string'},
        @{Name='VehicleId';Type='string'}, @{Name='StopId';Type='string'}, @{Name='StopSequence';Type='int64'},
        @{Name='ArrivalTimeUtc';Type='dateTime'}, @{Name='DepartureTimeUtc';Type='dateTime'}, @{Name='ArrivalDelaySeconds';Type='int64'},
        @{Name='DepartureDelaySeconds';Type='int64'}, @{Name='ScheduleRelationship';Type='string'}
    ); Measures=@(
        @{Name='Trip Update Count';Expression='COUNTROWS(TripPerformance)'},
        @{Name='Average Arrival Delay (min)';Expression='DIVIDE(AVERAGE(''TripPerformance''[ArrivalDelaySeconds]), 60)'},
        @{Name='Delayed Updates';Expression='CALCULATE(COUNTROWS(''TripPerformance''), ''TripPerformance''[ArrivalDelaySeconds] > 300)'}
    )}
    @{ File='ServiceAlerts.tmdl'; Name='ServiceAlerts'; View='vw_ServiceAlerts'; Columns=@(
        @{Name='ObservedAtUtc';Type='dateTime'}, @{Name='AlertId';Type='string'}, @{Name='Cause';Type='string'},
        @{Name='Effect';Type='string'}, @{Name='HeaderText';Type='string'}, @{Name='DescriptionText';Type='string'},
        @{Name='ActiveStartUtc';Type='dateTime'}, @{Name='ActiveEndUtc';Type='dateTime'}, @{Name='RouteId';Type='string'}, @{Name='StopId';Type='string'}
    ); Measures=@(
        @{Name='Alert Count';Expression='COUNTROWS(ServiceAlerts)'}
    )}
    @{ File='CalendarEvents.tmdl'; Name='CalendarEvents'; View='vw_CalendarEvents'; Columns=@(
        @{Name='EventDate';Type='dateTime'}, @{Name='EventName';Type='string'}, @{Name='EventType';Type='string'},
        @{Name='LocationName';Type='string'}, @{Name='Latitude';Type='double'}, @{Name='Longitude';Type='double'}
    ); Measures=@(
        @{Name='Event Count';Expression='COUNTROWS(CalendarEvents)'}
    )}
    @{ File='TrafficIncidents.tmdl'; Name='TrafficIncidents'; View='vw_TrafficIncidents'; Columns=@(
        @{Name='ObservedAtUtc';Type='dateTime'}, @{Name='IncidentId';Type='string'}, @{Name='IncidentStartUtc';Type='dateTime'},
        @{Name='IncidentEndUtc';Type='dateTime'}, @{Name='IncidentType';Type='string'}, @{Name='Severity';Type='string'},
        @{Name='Status';Type='string'}, @{Name='RoadName';Type='string'}, @{Name='Latitude';Type='double'}, @{Name='Longitude';Type='double'}
    ); Measures=@(
        @{Name='Incident Count';Expression='COUNTROWS(TrafficIncidents)'}
    )}
    @{ File='AirQuality.tmdl'; Name='AirQuality'; View='vw_AirQualityDaily'; Columns=@(
        @{Name='ObservationDate';Type='dateTime'}, @{Name='StationId';Type='string'}, @{Name='StationName';Type='string'},
        @{Name='AirQualityIndex';Type='int64'}, @{Name='PrimaryPollutant';Type='string'}, @{Name='Category';Type='string'}, @{Name='SmokeFlag';Type='boolean'}
    ); Measures=@(
        @{Name='AQI Days';Expression='COUNTROWS(AirQuality)'},
        @{Name='Average AQI';Expression='AVERAGE(''AirQuality''[AirQualityIndex])'}
    )}
    @{ File='ContextStatus.tmdl'; Name='ContextStatus'; View='vw_ContextDataStatus'; Columns=@(
        @{Name='DatasetName';Type='string'}, @{Name='RowCount';Type='int64'}, @{Name='Status';Type='string'},
        @{Name='SourceName';Type='string'}, @{Name='NextAction';Type='string'}
    ); Measures=@(
        @{Name='Context Datasets';Expression='COUNTROWS(ContextStatus)'},
        @{Name='Context Rows';Expression='SUM(''ContextStatus''[RowCount])'}
    )}
)

foreach ($table in $tableDefinitions) {
    $schemaName = if ($table.Schema) { $table.Schema } else { 'mart' }
    Write-Utf8 (Join-Path $ModelDefinitionFolder "tables\$($table.File)") (Sql-TableTmdl $table.Name $table.View $table.Columns $table.Measures $schemaName)
}

Write-Utf8 (Join-Path $ModelDefinitionFolder 'database.tmdl') @'
database
	compatibilityLevel: 1606
'@

$modelLines = [System.Collections.Generic.List[string]]::new()
$modelLines.Add('model Model')
$modelLines.Add("`tculture: en-US")
$modelLines.Add("`tdefaultPowerBIDataSourceVersion: powerBI_V3")
$modelLines.Add('')
$modelLines.Add('expression Server = "localhost" meta [IsParameterQuery=true, Type="Text", IsParameterQueryRequired=true]')
$modelLines.Add('expression Database = "SccTransitPoc" meta [IsParameterQuery=true, Type="Text", IsParameterQueryRequired=true]')
$modelLines.Add('')
foreach ($table in $tableDefinitions) {
    $modelLines.Add("ref table $($table.Name)")
}
Write-Utf8 (Join-Path $ModelDefinitionFolder 'model.tmdl') ($modelLines -join [Environment]::NewLine)
Write-Utf8 (Join-Path $ModelDefinitionFolder 'relationships.tmdl') @'
relationship Ridership_to_Stops
	fromColumn: Ridership.RouteId
	toColumn: Stops.RouteId
'@

$pageSpecs = @(
    @{Id='overview';Display='01 Ridership Overview';Visuals=@(
        @{Id='total';Type='cardVisual';Title='Total Boardings';Entity='Ridership';Field='Total Boardings';Role='Data';X=32;Y=24;W=270;H=120},
        @{Id='expected';Type='cardVisual';Title='Expected Riders';Entity='Ridership';Field='Expected Riders (Prior Year)';Role='Data';X=322;Y=24;W=270;H=120},
        @{Id='variance';Type='cardVisual';Title='Variance %';Entity='Ridership';Field='Variance %';Role='Data';X=612;Y=24;W=270;H=120},
        @{Id='trend';Type='lineChart';Title='Boardings by Period';Entity='Ridership';Field='Total Boardings';Category='PeriodStartDate';CategoryRole='Category';ValueRole='Y';X=32;Y=170;W=850;H=300},
        @{Id='service';Type='clusteredBarChart';Title='Boardings by Service';Entity='Ridership';Field='Total Boardings';Category='ServiceName';CategoryRole='Category';ValueRole='Y';X=900;Y=170;W=340;H=300},
        @{Id='status';Type='tableEx';Title='Data Status';Entity='Ridership';Fields=@('CalendarYear','ServiceName','RecordType','MetricName','MetricValue','DataStatus');X=32;Y=500;W=1208;H=180}
    )},
    @{Id='expected-vs-actual';Display='02 Expected vs Actual';Visuals=@(
        @{Id='actual';Type='cardVisual';Title='Actual Riders';Entity='Ridership';Field='Total Boardings';Role='Data';X=32;Y=24;W=270;H=120},
        @{Id='prior';Type='cardVisual';Title='Prior-Year Baseline';Entity='Ridership';Field='Expected Riders (Prior Year)';Role='Data';X=322;Y=24;W=270;H=120},
        @{Id='delta';Type='cardVisual';Title='Variance';Entity='Ridership';Field='Variance to Prior Year';Role='Data';X=612;Y=24;W=270;H=120},
        @{Id='trend';Type='lineChart';Title='Actual Demand Trend';Entity='Ridership';Field='Total Boardings';Category='PeriodStartDate';CategoryRole='Category';ValueRole='Y';X=32;Y=170;W=850;H=300},
        @{Id='route';Type='clusteredBarChart';Title='Demand by Route';Entity='Ridership';Field='Total Boardings';Category='RouteId';CategoryRole='Category';ValueRole='Y';X=900;Y=170;W=340;H=300},
        @{Id='detail';Type='tableEx';Title='Variance Detail';Entity='Ridership';Fields=@('CalendarYear','PeriodStartDate','ServiceName','RouteId','Total Boardings','Expected Riders (Prior Year)','Variance %');X=32;Y=500;W=1208;H=180}
    )},
    @{Id='service-detail';Display='03 Service Detail';Visuals=@(
        @{Id='service';Type='clusteredBarChart';Title='Boardings by Route';Entity='Ridership';Field='Total Boardings';Category='RouteId';CategoryRole='Category';ValueRole='Y';X=32;Y=24;W=600;H=300},
        @{Id='daytype';Type='clusteredBarChart';Title='Boardings by Day Type';Entity='Ridership';Field='Total Boardings';Category='DayTypeName';CategoryRole='Category';ValueRole='Y';X=650;Y=24;W=590;H=300},
        @{Id='detail';Type='tableEx';Title='Route and Service Detail';Entity='Ridership';Fields=@('CalendarYear','ServiceName','RouteId','LineTypeName','DayTypeName','MetricValue','DataStatus');X=32;Y=350;W=1208;H=330}
    )},
    @{Id='coverage';Display='04 Coverage & Stops';Visuals=@(
        @{Id='stops';Type='cardVisual';Title='Stop Count';Entity='Stops';Field='Stop Count';Role='Data';X=32;Y=24;W=270;H=120},
        @{Id='routes';Type='tableEx';Title='Stops and Coordinates';Entity='Stops';Fields=@('RouteId','StopId','StopName','StopLat','StopLon','WheelchairBoarding');X=32;Y=170;W=850;H=450},
        @{Id='wheelchair';Type='clusteredBarChart';Title='Stops by Accessibility Flag';Entity='Stops';Field='Stop Count';Category='WheelchairBoarding';CategoryRole='Category';ValueRole='Y';X=900;Y=170;W=340;H=300},
        @{Id='note';Type='tableEx';Title='GTFS Coverage Note';Entity='Stops';Fields=@('LocationType','ParentStation','StopCode');X=900;Y=500;W=340;H=120}
    )},
    @{Id='weather';Display='05 Weather Impact';Visuals=@(
        @{Id='days';Type='cardVisual';Title='Weather Days';Entity='Weather';Field='Weather Days';Role='Data';X=32;Y=24;W=270;H=120},
        @{Id='temp';Type='cardVisual';Title='Average Temperature F';Entity='Weather';Field='Average Temperature F';Role='Data';X=322;Y=24;W=270;H=120},
        @{Id='weather';Type='clusteredBarChart';Title='Weather Days by Human Perception';Entity='Weather';Field='Weather Days';Category='WeatherPerception';CategoryRole='Category';ValueRole='Y';X=32;Y=170;W=600;H=300},
        @{Id='condition';Type='tableEx';Title='Weather Detail';Entity='Weather';Fields=@('ObservationDate','StationName','WeatherPerception','TemperatureAvgF','PrecipitationInches','WindSpeedMph','WeatherCondition');X=650;Y=170;W=590;H=300},
        @{Id='join';Type='tableEx';Title='Ridership / Weather Join Readiness';Entity='Weather';Fields=@('ObservationDate','CalendarYear','WeatherPerception','ClassificationMethod');X=32;Y=500;W=1208;H=180}
    )},
    @{Id='operations';Display='06 Operations & Context';Visuals=@(
        @{Id='updates';Type='cardVisual';Title='Context Datasets';Entity='ContextStatus';Field='Context Datasets';Role='Data';X=32;Y=24;W=270;H=120},
        @{Id='alerts';Type='cardVisual';Title='Context Rows Available';Entity='ContextStatus';Field='Context Rows';Role='Data';X=322;Y=24;W=270;H=120},
        @{Id='incidents';Type='cardVisual';Title='Weather Rows Loaded';Entity='Weather';Field='Weather Days';Role='Data';X=612;Y=24;W=270;H=120},
        @{Id='delay';Type='clusteredBarChart';Title='Rows Available by Context Dataset';Entity='ContextStatus';Field='Context Rows';Category='DatasetName';CategoryRole='Category';ValueRole='Y';X=32;Y=170;W=600;H=300},
        @{Id='context';Type='tableEx';Title='Context Data Availability';Entity='ContextStatus';Fields=@('DatasetName','RowCount','Status','SourceName','NextAction');X=650;Y=170;W=590;H=300},
        @{Id='events';Type='tableEx';Title='Operational Feed Status';Entity='ContextStatus';Fields=@('DatasetName','Status','RowCount','NextAction');X=32;Y=500;W=600;H=180},
        @{Id='aqi';Type='tableEx';Title='Context Sources';Entity='ContextStatus';Fields=@('DatasetName','SourceName','Status');X=650;Y=500;W=590;H=180}
    )}
)

function Field-Projection([string]$Entity, [string]$Property, [string]$Kind, [string]$QueryRef) {
    if ($Kind -eq 'Measure') {
        return [ordered]@{ field = [ordered]@{ Measure = [ordered]@{ Expression = [ordered]@{ SourceRef = @{ Entity = $Entity } }; Property = $Property } }; queryRef = $QueryRef; nativeQueryRef = $Property }
    }
    return [ordered]@{ field = [ordered]@{ Column = [ordered]@{ Expression = [ordered]@{ SourceRef = @{ Entity = $Entity } }; Property = $Property } }; queryRef = $QueryRef; nativeQueryRef = $Property }
}

function Visual-Json($spec, [int]$tabOrder) {
    $queryState = [ordered]@{}
    if ($spec.Type -eq 'cardVisual') {
        $queryState['Data'] = @{ projections = @((Field-Projection $spec.Entity $spec.Field 'Measure' "$($spec.Entity).$($spec.Field)")) }
    } elseif ($spec.Type -eq 'slicer') {
        $queryState['Values'] = @{ projections = @((Field-Projection $spec.Entity $spec.Field 'Column' "$($spec.Entity).$($spec.Field)")) }
    } elseif ($spec.Type -eq 'tableEx') {
        $projections = @()
        foreach ($field in $spec.Fields) {
            $isMeasure = $field -in @('Total Boardings','Expected Riders (Prior Year)','Variance to Prior Year','Variance %','Average Metric Value','Stop Count','Trip Update Count','Average Arrival Delay (min)','Delayed Updates','Alert Count','Event Count','Incident Count','AQI Days','Average AQI','Weather Days','Average Temperature F','Average Precipitation','Context Datasets','Context Rows')
            $projections += Field-Projection $spec.Entity $field ($(if ($isMeasure) {'Measure'} else {'Column'})) "$($spec.Entity).$field"
        }
        $queryState['Values'] = @{ projections = $projections }
    } else {
        $category = Field-Projection $spec.Entity $spec.Category 'Column' "$($spec.Entity).$($spec.Category)"
        $value = Field-Projection $spec.Entity $spec.Field 'Measure' "$($spec.Entity).$($spec.Field)"
        $queryState['Category'] = @{ projections = @($category) }
        $queryState[$spec.ValueRole] = @{ projections = @($value) }
    }
    return [ordered]@{
        '$schema' = 'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.7.0/schema.json'
        name = $spec.Id
        position = @{ x=$spec.X; y=$spec.Y; z=0; height=$spec.H; width=$spec.W; tabOrder=$tabOrder }
        visual = @{ visualType=$spec.Type; query=@{ queryState=$queryState }; drillFilterOtherVisuals=$true }
    }
}

$pageOrder = @()
foreach ($page in $pageSpecs) {
    $pageOrder += $page.Id
    $pagePath = Join-Path $PagesFolder $page.Id
    Ensure-Directory (Join-Path $pagePath 'visuals')
    Write-Json (Join-Path $pagePath 'page.json') ([ordered]@{
        '$schema'='https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.1.0/schema.json'
        name=$page.Id; displayName=$page.Display; displayOption='FitToPage'; height=720; width=1280
    })
    $tab = 0
    foreach ($visual in $page.Visuals) {
        $visualPath = Join-Path (Join-Path $pagePath 'visuals') $visual.Id
        Ensure-Directory $visualPath
        Write-Json (Join-Path $visualPath 'visual.json') (Visual-Json $visual $tab)
        $tab++
    }
}

Write-Json (Join-Path $PagesFolder 'pages.json') ([ordered]@{
    '$schema'='https://developer.microsoft.com/json-schemas/fabric/item/report/definition/pagesMetadata/1.0.0/schema.json'
    pageOrder=$pageOrder; activePageName='overview'
})

Write-Utf8 (Join-Path $ProjectRoot 'powerbi\README.md') @'
# SCC Transit Power BI POC

Open `SccTransitPoc.pbip` in Power BI Desktop. The PBIP report connects to the local SQL Server database `SccTransitPoc` on `localhost` and imports the `mart` views.

Pages included:

1. Ridership Overview
2. Expected vs Actual
3. Service Detail
4. Coverage & Stops
5. Weather Impact
6. Operations & Context

The 2026 source data is partial-year. The Operations & Context page includes feed availability status; realtime, events, traffic, and air-quality row counts remain zero until their corresponding source feeds are loaded. Weather data can be seeded with `scripts/load_noaa_weather.ps1`.

The seed report uses source-controlled DAX measures for cards and charts. The installed Desktop build requires TMDL measures to use standard bracketed column references.
'@

Write-Utf8 (Join-Path $ProjectRoot 'powerbi\.gitignore') @'
**/.pbi/localSettings.json
**/.pbi/cache.abf
'@

Write-Output "Created Power BI project: $(Join-Path $ProjectRoot "powerbi\$ProjectName.pbip")"
