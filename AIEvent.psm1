
<#
.Synopsis
   Send a Custom Event to Application Insights.
   A custom event is a data point that you can display both in in Metrics Explorer as an aggregated count, 
   and also as individual occurrences in Diagnostic Search 
.EXAMPLE
    Send-AIEvent -Event "Starting Import Run"

.EXAMPLE

    Function Log ($Message = ""){
        Write-verbose $Message 
        Send-AIEvent -Event $Message -StackWalk 1 #One additional Step up in the PSStack
    }

.EXAMPLE
    Send-AIEvent -Event "Starting Import Run"

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
        [Microsoft.ApplicationInsights.TelemetryClient] $Client ,
       
        #any custom Properties that need to be added to the event 
        [Hashtable]$Properties,
        #any custom metrics that need to be added to the event 
        [Hashtable]$Metrics,
        #include call stack  information (Default)
        [switch] $NoStack,
        #The number of Stacklevels to go up 
        [int]$StackWalk = 0,
        #Directly flush the AI events to the service
        [switch] $Flush

    )
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
    $dictMetrics = New-Object 'system.collections.generic.dictionary[[string],[double]]'

    #Send the callstack
    if ($NoStack -ne $True) { 
        $dictProperties = getCallerInfo -level (2+$StackWalk)
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
