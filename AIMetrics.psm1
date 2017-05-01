<#
.Synopsis
    Send a metric in the format of Key = Value 

    Use TrackMetric to send metrics that are not attached to particular events. For example, you could monitor a queue length at regular intervals. 
    Metrics are displayed as statistical charts in metric explorer, but unlike events, you can't search for individual occurrences in diagnostic search.

    Number
    ------
    A string that identifies the metric. In the portal, you can select metrics for display by name.

    Average
    -------
    Either a single measurement, or the average of several measurements. Should be >=0 to be correctly displayed.

    SampleCount
    -----------
    Count of measurements represented by the average. Defaults to 1. Should be >=1.

    min
    ---
    The smallest measurement in the sample. Defaults to the average. Should be >= 0.
    
    max
    ---
    The largest measurement in the sample. Defaults to the average. Should be >= 0.

.EXAMPLE
        #Report the amount of work in the Q
        Send-AIMetric -Metric "InputQueue" -Value $Q.Count

.EXAMPLE
        #Send a range of metrics 
        1..100 | %{ 
            Send-AIMetric -Metric "Counter" -Value $_ -NoStack 
        }

.EXAMPLE
        $Result = Invoke-SQLQuery -query "Select Count(*) as Users from $TableName" -connection $Connection 
        Send-AIMetric -Metric "UsersInDatabase" -Value $Result.Users

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
        [Microsoft.ApplicationInsights.TelemetryClient] $Client ,

        #include call stack  information (Default)
        [switch] $NoStack,
        #The number of Stacklevels to go up 
        [int]$StackWalk = 0,

        #Directly flush the AI events to the service
        [switch] $Flush

    )
    Write-Verbose "Send-AIMetric $Metric = $Value"
    #Check for a specified AI client
    if ($Client -eq $null) {
        If ( ($Global:AISingleton ) -AND ( $Global:AISingleton.Client ) ) {
            #Use Current Client
            $Client = $Global:AISingleton.Client
        }
    }
    #no need to do anything if there is no client
    if ($Client -eq $null) { 
        Write-Verbose 'No AI Client found'
        return 
    }  

    #Setup dictionaries     
    $dictProperties = New-Object 'system.collections.generic.dictionary[[string],[string]]'

    #Add the callstack
    if ($NoStack -ne $True) { 
        Write-verbose 'Add Caller information'
        $dictProperties = getCallerInfo -level (2+$StackWalk)
    }
    #Add the Properties to Dictionary
    if ($Properties) { 
        foreach ($h in $Properties.GetEnumerator() ) {
            $dictProperties.Add($h.Name, $h.Value)
        }
    }
    #Send the Metric 
    $client.trackMetric($Metric, $Value, $dictProperties);

    #Flush the client is requested
    if ($Flush) { 
        $client.Flush()
    }
}



