<#
.Synopsis
    Handle sending exceptions and Powershell errors via App Insights

#>
function Send-AIException
{
    [CmdletBinding()]
    #[OutputType([int])]
    Param
    (
        # An Error from a catch clause.
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [System.Exception] $Exception,

        #Defaults to "unhandled"
        $HandledAt = $null,


        #Map of string to string: Additional data used to filter pages in the portal.
        $Properties = $null,
        #Map of string to number: Metrics associated with this page, displayed in Metrics Explorer on the portal. 
        $Metrics = $null,

        #The Severity of the Exception 0 .. 4 : Default = 2
        $Severity = 2, 

        #The AppInsights Client object to use.
        [Parameter(Mandatory=$false)]
        [Microsoft.ApplicationInsights.TelemetryClient] $Client = $Global:AISingleton.Client,

<#        
        #include call stack  information (Default)
        [switch] $NoStack,
        #The number of Stacklevels to go up 
        [int]$StackWalk = 0,
#>
        #Directly flush the AI events to the service
        [switch] $Flush

    )
    #Check for a specified AI client
    if ($Client -eq $null) {
        throw [System.Management.Automation.PSArgumentNullException]::new($script:ErrNoClient)
    }

    #Setup dictionaries     
#    $dictProperties = New-Object 'system.collections.generic.dictionary[[string],[string]]'
#    $dictMetrics = New-Object 'system.collections.generic.dictionary[[string],[double]]'
    $AIExeption = New-Object Microsoft.ApplicationInsights.DataContracts.ExceptionTelemetry
<#
    #Send the callstack
    if ($NoStack -eq $false) { 
        $dictProperties = getCallerInfo -level (2+$StackWalk)
        #? Add the caller info
        $AIExeption.Properties.Add($dictProperties)
    }
#>
    #Add the Properties to Dictionary
    if ($Properties) { 
        foreach ($h in $Properties.GetEnumerator() ) {
            ($AIExeption.Properties).Add($h.Name, $h.Value)
        }
    }
    #Convert metrics to Dictionary
    if ($Metrics) { 
        foreach ($h in $Metrics.GetEnumerator()) {
            ($AIExeption.Metrics).Add($h.Name, $h.Value)
        }
    }
    $AIExeption.Exception = $Exception

    #$client.TrackEvent($AIExeption)

    $client.TrackException($Exception) 
    #$client.TrackException($Exception, $HandledAt, $Properties, $Metrics, $Severity) 



    <#

        exception
        An Error from a catch clause.
        handledAt
        Defaults to "unhandled".
        properties
        Map of string to string: Additional data used to filter exceptions in the portal. Defaults to empty.
        measurements
        Map of string to number: Metrics associated with this page, displayed in Metrics Explorer on the portal. Defaults to empty.
        severityLevel
        Supported values: SeverityLevel.ts

            SeverityLevel[SeverityLevel["Verbose"] = 0] = "Verbose";
            SeverityLevel[SeverityLevel["Information"] = 1] = "Information";
            SeverityLevel[SeverityLevel["Warning"] = 2] = "Warning";
            SeverityLevel[SeverityLevel["Error"] = 3] = "Error";
            SeverityLevel[SeverityLevel["Critical"] = 4] = "Critical";


        void TrackException(System.Exception exception, 
                            System.Collections.Generic.IDictionary[string,string] properties, 
                            System.Collections.Generic.IDictionary[string,double] metrics)
    #>    
    
    if ($Flush) { 
        $client.Flush()
    }
}
