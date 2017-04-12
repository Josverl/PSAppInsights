<#
.Synopsis
    Send a metric in the format of Key = Value 

    Use TrackMetric to send metrics that are not attached to particular events. For example, you could monitor a queue length at regular intervals. 
    Metrics are displayed as statistical charts in metric explorer, but unlike events, you can't search for individual occurrences in diagnostic search.

Number 
    A string that identifies the metric. In the portal, you can select metrics for display by name.

Average
    Either a single measurement, or the average of several measurements. Should be >=0 to be correctly displayed.

SampleCount
    Count of measurements represented by the average. Defaults to 1. Should be >=1.

min
    The smallest measurement in the sample. Defaults to the average. Should be >= 0.
max
    The largest measurement in the sample. Defaults to the average. Should be >= 0.

properties
    Map of string to string: Additional data used to filter events in the portal.

.EXAMPLE
   Example of how to use this cmdlet
#>
function Send-AIMetric
{
    [CmdletBinding()]
    #[OutputType([int])]
    Param
    (
        # The Trace Message
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [string] $Metric,

        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [double] $Value,

        #any custom Properties that need to be added to the event 
        [Hashtable]$Properties,

        #The AppInsights Client object to use.
        [Parameter(Mandatory=$false)]
        [Microsoft.ApplicationInsights.TelemetryClient] $Client = $Global:AISingleton.Client,

        #include call stack  information (Default)
        [switch] $NoStack,

        #Directly flush the AI events to the service
        [switch] $Flush

    )
    Write-Verbose "Send-AIMetric $Metric = $Value"
    #Check for a specified AI client
    if ($Client -eq $null) {
        throw [System.Management.Automation.PSArgumentNullException]::new($script:ErrNoClient)
    }
    #Setup dictionaries     
    $dictProperties = New-Object 'system.collections.generic.dictionary[[string],[string]]'

    #Send the callstack
    if ($NoStack -eq $false) { 
        Write-verbose 'Add Caller information'
        $dictProperties = getCallerInfo -level 2
    }
    #Add the Properties to Dictionary
    if ($Properties) { 
        foreach ($h in $Properties.GetEnumerator() ) {
            $dictProperties.Add($h.Name, $h.Value)
        }
    }
    Write-Verbose "Send-AIMetric $Metric = $Value"
    $client.trackMetric($Metric, $Value, $dictProperties);

   # $client.trackMetric.OverloadDefinitions

    if ($Flush) { 
        $client.Flush()
    }
}

