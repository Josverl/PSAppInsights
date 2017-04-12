
<#
.Synopsis
    Start collection perfromance counters and send them to App Insights
.DESCRIPTION
    The collection includes perf counters of the powershell process tha runs the script.
   
    By default the following perf counters are collected : 
    - Handle Count 
    - Working Set 

    If other process counters are to be collected these can be specified using -ProcessCounters
    (currently only process counters are supported)

    The perfmon collector is mantained per (powershell) process, and a reference to the collectore is stored in a global variable.
    $Global:AISingleton.PerformanceCollector

    By default the counters are collected and sent every 30 seconds
.Component
    The implementation makes use of the Microsoft.ApplicationInsights.PerfCounterCollector package
.LINK    
    https://azure.microsoft.com/en-us/documentation/articles/app-insights-web-monitor-performance/#system-performance-counters
.EXAMPLE
    #Start logging the default set of perf counters 

    Start-AIPerformanceCollector -Key "c90dd0dd-1111-2222-3333-ddb55873d30a'

.EXAMPLE
    #Start logging all process counters 

    #get list of all process counters  
    $ProcessCounters = (Get-Counter -ListSet "Process").paths | %{ $_.Split('\')[2]}

    #Start logging
    Start-AIPerformanceCollector -Key $key -ProcessCounters $ProcessCounters
#>
function Start-AIPerformanceCollector
{
    [CmdletBinding()]
    Param(
        # The App Insights Key 
        [Parameter(Mandatory=$true)] 
        $Key,
        #Process Counters of the powershell process to collect 
        [string[]]
        $ProcessCounters = @( 'Handle Count', 'Working Set' ),
        
        #Send through Fiddler for debugging
        [switch]$Fiddler
    )
    #Stop Collector if it was already running 
    if ($Global:AISingleton.PerformanceCollector) { 
        Stop-AIPerformanceCollector 
    }

    Write-Verbose "Create AI Performance Collector Instance"
    $Global:AISingleton.PerformanceCollector = New-Object  Microsoft.ApplicationInsights.Extensibility.PerfCounterCollector.PerformanceCollectorModule

    Write-Verbose "Add ??APP_WIN32_PROC?? performance counters"
    $ProcessName =  ([System.Diagnostics.Process]::GetCurrentProcess()).ProcessName 
    foreach ( $c in $ProcessCounters ) { 
        $Counter = "\Process($ProcessName)\$c"
        $CollectionRequest = New-Object  Microsoft.ApplicationInsights.Extensibility.PerfCounterCollector.PerformanceCounterCollectionRequest -ArgumentList $Counter, $c
        $Global:AISingleton.PerformanceCollector.Counters.Add( $CollectionRequest)
    } 
    #Add Processes
    $CollectionRequest = New-Object  Microsoft.ApplicationInsights.Extensibility.PerfCounterCollector.PerformanceCounterCollectionRequest -ArgumentList "\Objects\Processes", "Processes"
    $Global:AISingleton.PerformanceCollector.Counters.Add( $CollectionRequest)

    if ($Fiddler) {
        Write-Verbose "Send though fiddler for debugging" 
        [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.TelemetryChannel.EndpointAddress = 'http://localhost:8888/v2/track'
    }
    Write-Verbose "Initialize"
    [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.InstrumentationKey = $key
    $Global:AISingleton.PerformanceCollector.Initialize( [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active )
}

<#
.Synopsis
    Stops the logging of performance monitor counters,
    or returns a warning if the collector was not started.
.Component
    The implementation makes use of the Microsoft.ApplicationInsights.PerfCounterCollector package
.LINK    
    https://azure.microsoft.com/en-us/documentation/articles/app-insights-web-monitor-performance/#system-performance-counters
 
.EXAMPLE
    Stop-AIPerformanceCollector
#>
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


<#
.Synopsis
    Starts logging a live metrics stream to App Insights
.DESCRIPTION
    The logging stream sends a standard set of perfcounters every second, which allows you to monitor essential counters directly in AppInsights.
    
    Please note that this will incur a continous stream of performance and statictics to the azure AppInsights portal,
    this is in the format of a HTTPS traffic stream which will send about 5 to 6 MBytes per hour to https://rt.services.visualstudio.com

    This information is sent asynchronously from the powershell script or module and requires no interaction other that starting or stopping.
    Please note that there is only a single LiveMetrics view for each Instrumentation key.
    > If multiple instances of the same script log to the same Key the counters will be combines
    > if you need to view seperate LiveMetrics, you need to instrument your scripts with different keys.

    Implementation uses the Microsoft.ApplicationInsights.PerfCounterCollector package
.Note 
    As Powershell scripts are not the main scenario, there are a number of metrics that are not relevant
    the current implementation does support : 
    - Server Health 
        - Memory 
        - CPU 

    -Incoming Requests
        - Not relevant for Powershell

    Future capabilities :

    - Dependency Calls  - Requires explicit dependency tracking
        - Calls/Sec 
        - Duration
        - Failed/Sec

.Link 
    https://azure.microsoft.com/en-us/blog/live-metrics-stream/

.Link 
    Send-AIDependecy

.EXAMPLE
    #Start sending of live performance data
    Start-AILiveMetrics -key $key

.EXAMPLE
    #Start sending of live performance data, 
    #but limit the inclusion of telemetry items; (note that this functionality is not yet fully implemented) 

    Start-AILiveMetrics -key $key -DisableFullTelemetryItems
#>
function Start-AILiveMetrics
{
[CmdletBinding()]
[Alias('Start-AIQuickPulse')]
[OutputType([void])]
Param
(
    # Param1 help description
    [Parameter(Mandatory=$false)]
    [string]$Key= [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.InstrumentationKey  #Get earlier provided / current key
        
    # DisableFullTelemetryItems - #Needs QuickPulse Processor to provide statistics
    #[switch]$DisableFullTelemetryItems
)

    #Make sure a Key is set if one is provided
    if ( [string]::IsNullOrEmpty($key) -eq $false) {
        Write-verbose 'Start-AILiveMetrics - Save IKey'
        # This is a singleton that controls all New AI Client sessions for this process from this moment 
        [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.InstrumentationKey = $key
    }

    #Check for a specified AI client
    if ([Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.InstrumentationKey -eq $null) {
        throw [System.Management.Automation.PSArgumentNullException]::new($Global:AISingleton.ErrNoClient)
    }

    #If one is running : Close it 
    if ($Global:AISingleton.QuickPulse) {
        Write-verbose "Start-AILiveMetrics - Stop and replace existing Live Metrics"
        Stop-AIQuickPulse
    }
    
    #Create a new QuickPulse / LiveMetric Processor
    $Global:AISingleton.QuickPulse = [Microsoft.ApplicationInsights.Extensibility.PerfCounterCollector.QuickPulse.QuickPulseTelemetryModule]::new()

    #Copy the settings 
    # $Global:AISingleton.QuickPulse.DisableFullTelemetryItems = $DisableFullTelemetryItems
     Write-verbose "Start-AILiveMetrics - Initialize"
    $Global:AISingleton.QuickPulse.Initialize( [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active )
}

<#
.Synopsis
   Stop the sending of Live metrics for this powershell process.
.EXAMPLE
   Stop-AILiveMetrics
#>
function Stop-AILiveMetrics 
{
[CmdletBinding()]
[Alias('Stop-AIQuickPulse')]
[OutputType([void])]
Param
()
    #If one is running : Close it 
    if ($Global:AISingleton.QuickPulse) {
         Write-verbose "Stop-AILiveMetrics - Stoppingand disposing client"
        $Global:AISingleton.QuickPulse.Dispose()
        $Global:AISingleton.QuickPulse = $null
    } else {
        Write-Warning "Application Insights Live Metrics not Started"

    }
}
