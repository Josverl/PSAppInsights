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
    http://apmtips.com/blog/2017/02/13/enable-application-insights-live-metrics-from-code/
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
    # Instrumentation key
    [Parameter(Mandatory=$false)]
    [string]$Key= [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.InstrumentationKey  #Get earlier provided / current key
        
    # DisableFullTelemetryItems - #Needs QuickPulse Processor to provide statistics
    #[switch]$DisableFullTelemetryItems
)

#TODO : Verify Implementation : http://apmtips.com/blog/2017/02/13/enable-application-insights-live-metrics-from-code/
#TODO Add options for DisableFullTelemetryItems DisableTopCpuProcesses ?

    Try { 
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

<#        void Initialize(
                Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration, 
                Microsoft.ApplicationInsights, Version=2.3.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35 configuration)
        void ITelemetryModule.Initialize(Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration, Microsoft.ApplicationInsights, Version=2.3.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35 configuration)
#>
    } catch { 
        $ex = $_ 
        Write-Warning "Could not initialise AI Live Metrics"
    }
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
         Write-verbose "Stop-AILiveMetrics - Stopping and disposing client"
        $Global:AISingleton.QuickPulse.Dispose()
        $Global:AISingleton.QuickPulse = $null
    } else {
        Write-Warning "Application Insights Live Metrics not Started"

    }
}
