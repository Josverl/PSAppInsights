
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
        [switch]$Fiddler,
        
        #When developer mode is True, sends telemetry to Application Insights immediately during the entire lifetime of the application
        [switch]$DeveloperMode,

        # Sets the maximum telemetry batching interval in seconds. Once the interval expires, sends the accumulated telemetry items for transmission.
        [ValidateRange(0, 1440)] #Up to day should be sufficient
        $SendingInterval = 0
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

    #Activate/deactivate developermode 
    if ($DeveloperMode) {
        Write-Verbose "Set DeveloperMode" 
        [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.TelemetryChannel.DeveloperMode = $true
    } else {
        Write-Verbose "Set DeveloperMode off" 
        [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.TelemetryChannel.DeveloperMode = $false
    }

    If ($SendingInterval -ne 0)
    {        
        Write-Verbose "Set Bufferdelay to $SendingInterval seconds." 
        [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.TelemetryChannel.SendingInterval = New-TimeSpan -Seconds $SendingInterval
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


