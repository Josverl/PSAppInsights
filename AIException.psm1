<#
.Synopsis
    Handle sending exceptions and Powershell errors via App Insights

    Two events will be sent : 
    - A Trace event with the PowerShell Stack information 
    - A (Client) exception event 
#>
function Send-AIException
{
    [CmdletBinding(DefaultParameterSetName = "Exception")]
    #[OutputType([int])]
    Param
    (
        # An Exception from a catch clause.
        [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)]
        [Parameter(ParameterSetName='Exception')]
        [System.Exception] $Exception,

        #Defaults to "unhandled"
        [Parameter(ParameterSetName='Exception')]
        $HandledAt = $null,

        # An Exception from a catch clause.
        [Parameter(Mandatory=$False,ValueFromPipelineByPropertyName=$true)]
        [Parameter(ParameterSetName='Error')]
        #[System.Management.Automation.ErrorRecord]
        $ErrorInfo,

        #Map of string to string: Additional data used to filter pages in the portal.
        $Properties = $null,
        #Map of string to number: Metrics associated with this page, displayed in Metrics Explorer on the portal. 
        $Metrics = $null,

        #The Severity of the Exception 0 .. 4 : Default = 4 (Error)
        $Severity = 'Error', 

        #The AppInsights Client object to use.
        [Parameter(Mandatory=$false)]
        [Microsoft.ApplicationInsights.TelemetryClient] $Client ,
        
        #include call stack  information (Default)
        [switch] $NoStack,
        #The number of Stacklevels to go up 
        [int]$StackWalk = 0,

        #Directly flush the AI events to the service (Default:$True)
        [switch]$Flush=$true

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


    #Create a new empty AIException object
    $AIExeption = New-Object Microsoft.ApplicationInsights.DataContracts.ExceptionTelemetry


    #If an exception was passed in then 
    If ( $PsCmdlet.ParameterSetName -ieq 'Exception' ) { 
        #Add The exeption 
        $AIExeption.Exception = $Exception

        #Send the PowerShell StackTrace and additional info in an AI Trace
        $MSG = "PSSCallStack for exception: {0}" -f $Exception.ToString()
        Send-AITrace -Message $MSG -NoStack:$NoStack -Properties $Properties -Client:$Client -StackWalk:($StackWalk+1) -FullStack -SeverityLevel 'Error'

    } 
    
    #If an Error  was passed in then 
    If ( $PsCmdlet.ParameterSetName -ieq 'Error' ) { 

        $AIExeption.Exception = $ErrorInfo.Exception

        #Send the PowerShell StackTrace and additional info in an AI Trace
        $MSG = "PSSCallStack for Error: {0}" -f $ErrorInfo.ToString()
        $ErrProperties = ( $ErrorInfo | Select -ExcludeProperty InvocationInfo | ConvertTo-Hashtable ) `
                       + ( $ErrorInfo.InvocationInfo | Select -ExcludeProperty Line,PositionMessage |  ConvertTo-Hashtable )
        Send-AITrace -Message $MSG -NoStack:$NoStack -Properties $ErrProperties -Client:$Client -StackWalk:($StackWalk+1) -FullStack -SeverityLevel 'Error'

    }
    
    #ToDo : Linkup Operation ID ?

    #Add the PowerShell callstack (Full) 
    #Note this is apparently ignored by AI 
<#    
    if ($NoStack -ne $True) { 
        $dictProperties = getCallerInfo -level (2+$StackWalk) -FullStack 
        #Add the caller info in the callstack 
        foreach ($Prop in $dictProperties.GetEnumerator()) {
            $Result = $AIExeption.Properties.TryAdd($Prop.Key, $Prop.Value)
            #Write-Verbose $Result -Verbose
        }
    }
    #Add the Properties to Dictionary
    #Note this is apparently ignored by AI 
    if ($Properties) { 
        foreach ($Prop in $Properties.GetEnumerator() ) {
            $Result = $AIExeption.Properties.TryAdd($Prop.Key, $Prop.Value)
            Write-Verbose $Result -Verbose
        }
    }
    #Add metrics to Dictionary
    #Note this is apparently ignored by AI 
    if ($Metrics) { 
        foreach ($Metric in $Metrics.GetEnumerator()) {
            $AIExeption.Metrics.TryAdd($Metric.Name, $Metric.Value)
            Write-Verbose $Result -Verbose
        }
    }
    #>

    #Send the exeption to AI 
    $client.TrackException($AIException) 

    <#
    #$client.TrackException($Exception, $HandledAt, $Properties, $Metrics, $Severity) 

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
