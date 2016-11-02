
<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
#>
function start-AIPerformanceCollector
{
    [CmdletBinding()]
    Param(
        # The App Insights Key 
        [Parameter(Mandatory=$true)] 
        $Key,
        #Process Counters of the powershell process to collect 
        [string[]]
        $ProcessCounters = @( 'Handle Count', 'Working Set' )
        # @todo Set to suppress sending messages in a test environment
        # [string]$Synthetic

    )
    if ($Global:AISingleton.PerformanceCollector) { Stop-AIPerformanceCollector }
    Write-Verbose "Create AI Performance Collector Instance"
    $Global:AISingleton.PerformanceCollector = New-Object  Microsoft.ApplicationInsights.Extensibility.PerfCounterCollector.PerformanceCollectorModule

    Write-Verbose "Add ??APP_WIN32_PROC?? performance counters"
    #$ProcessName =  "??{0}??" -f ([System.Diagnostics.Process]::GetCurrentProcess()).ProcessName
    $ProcessName =  ([System.Diagnostics.Process]::GetCurrentProcess()).ProcessName 
    foreach ( $c in $ProcessCounters ) { 
        $Counter = "\Process($ProcessName)\$c"
        $CollectionRequest = New-Object  Microsoft.ApplicationInsights.Extensibility.PerfCounterCollector.PerformanceCounterCollectionRequest -ArgumentList $Counter, $c
        $Global:AISingleton.PerformanceCollector.Counters.Add( $CollectionRequest)
    } 
    #Add Processes
    $CollectionRequest = New-Object  Microsoft.ApplicationInsights.Extensibility.PerfCounterCollector.PerformanceCounterCollectionRequest -ArgumentList "\Objects\Processes", "Processes"
    $Global:AISingleton.PerformanceCollector.Counters.Add( $CollectionRequest)

<# Debug 
    [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.TelemetryChannel.EndpointAddress = 'http://localhost:8888/v2/track'
#>    Write-Verbose "Initialize"
    [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.InstrumentationKey = $key
    $Global:AISingleton.PerformanceCollector.Initialize( [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active )}

function Stop-AIPerformanceCollector
{
    [CmdletBinding()]
    Param()

    if ($Global:AISingleton.PerformanceCollector) {
        Write-Verbose "Stoping Performance counter collection"
        $Global:AISingleton.PerformanceCollector.Dispose()
        $Global:AISingleton.PerformanceCollector = $null
    }
}

