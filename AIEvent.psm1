
<#
.Synopsis
   Send a Custom Event to Application Insights.
   A custom event is a data point that you can display both in in Metrics Explorer as an aggregated count, 
   and also as individual occurrences in Diagnostic Search 
.EXAMPLE
   Example of how to use this cmdlet
#>
function Send-AIEvent
{
    [CmdletBinding()]
    #[OutputType([int])]
    Param
    (
        # The Trace Message
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [string] $Event,
        #The AppInsights Client object to use.
        [Parameter(Mandatory=$false)]
        [Microsoft.ApplicationInsights.TelemetryClient] $Client = $Global:AISingleton.Client,
       
        #any custom Properties that need to be added to the event 
        [Hashtable]$Properties,
        #any custom metrics that need to be added to the event 
        [Hashtable]$Metrics,
        #include call stack  information (Default)
        [switch] $NoStack,
        #Directly flush the AI events to the service
        [switch] $Flush

    )
    #Check for a specified AI client
    if ($Client -eq $null) {
        throw [System.Management.Automation.PSArgumentNullException]::new($script:ErrNoClient)
    }

    #Setup dictionaries     
    $dictProperties = New-Object 'system.collections.generic.dictionary[[string],[string]]'
    $dictMetrics = New-Object 'system.collections.generic.dictionary[[string],[double]]'

    #Send the callstack
    if ($NoStack -eq $false) { 
        $dictProperties = getCallerInfo -level 2
    }
    #Add the Properties to Dictionary
    if ($Properties) { 
        foreach ($h in $Properties.GetEnumerator() ) {
            $dictProperties.Add($h.Name, $h.Value)
        }
    }
    #Convert metrics to Dictionary
    if ($Metrics) { 
        foreach ($h in $Metrics.GetEnumerator()) {
            $dictMetrics.Add($h.Name, $h.Value)
        }
    }
    #Send the event 
    $client.TrackEvent($Event, $dictProperties , $dictMetrics) 
    
    if ($Flush) { 
        $client.Flush()
    }
}
