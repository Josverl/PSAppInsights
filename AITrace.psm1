<#
.Synopsis
   Send a trace message to Application Insights 
.EXAMPLE
   Example of how to use this cmdlet
#>
function Send-AITrace
{
    [CmdletBinding()]
    #[OutputType([int])]
    Param
    (
        # The Trace Message
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [string] $Message,
        
        #Severity, Defaults to Information
        [Parameter()]
        [Alias("Severity")]
        $SeverityLevel = [Microsoft.ApplicationInsights.DataContracts.SeverityLevel]::Information, 
        #any custom Properties that need to be added to the trace 
        [Hashtable]$Properties,


        #include call stack  information (Default)
        [switch] $NoStack,
        #The number of Stacklevels to go up 
        [int]$StackWalk = 0,

        #The AppInsights Client object to use.
        [Parameter(Mandatory=$false)]
        [Microsoft.ApplicationInsights.TelemetryClient] $Client = $Global:AISingleton.Client,

        #Directly flush the AI events to the service
        [switch] $Flush
    )
    #Check for a specified AI client
    if ($Client -eq $null) {
        throw [System.Management.Automation.PSArgumentNullException]::new($Global:AISingleton.ErrNoClient)
    }
    #Setup dictionaries     
    $dictProperties = New-Object 'system.collections.generic.dictionary[[string],[string]]'

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
    $sev = [Microsoft.ApplicationInsights.DataContracts.SeverityLevel]$SeverityLevel

    $client.TrackTrace($Message, $Sev, $dictProperties)
    #$client.TrackTrace($Message)
    
    if ($Flush) { 
        $client.Flush()
    }
}

