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


        #Disable include call stack information of the caller
        [switch] $NoStack,
        #include All call stack information 
        [switch] $FullStack,
        
        #The number of Stacklevels to go up 
        [int]$StackWalk = 0,

        #The AppInsights Client object to use.
        [Parameter(Mandatory=$false)]
        [Microsoft.ApplicationInsights.TelemetryClient] $Client ,

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

    #Send the callstack
    if ($NoStack -ne $True) { 
        $dictProperties = getCallerInfo -level (2+$StackWalk) -FullStack:$FullStack
    }
    #Add the Properties to Dictionary
    if ($Properties) { 
        foreach ($h in $Properties.GetEnumerator() ) {
            Try { 
                $dictProperties.Add($h.Name, $h.Value)
            } Catch [ArgumentException] {
                Write-Verbose "Could not add $($h.Name)"
            }
        }
    }
    $sev = [Microsoft.ApplicationInsights.DataContracts.SeverityLevel]$SeverityLevel

    $client.TrackTrace($Message, $Sev, $dictProperties)
    #$client.TrackTrace($Message)
    if ($Flush) { 
        $client.Flush()
    }
}

