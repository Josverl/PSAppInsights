<#
 # Dependency
#>



function new-Stopwatch
{
    return [System.Diagnostics.Stopwatch]::StartNew();
}


<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>

function Send-AIDependency
{
    [CmdletBinding()]
    [OutputType([void])]
    Param
    (
         # TimeSpan as measured by measure-command (Pipeline) 
        [Parameter(Mandatory=$false,ValueFromPipeline=$true)]
        [System.TimeSpan] $TimeSpan, 

        # Stopwatch 
        [Parameter(Mandatory=$false)]
        [System.Diagnostics.Stopwatch]$StopWatch,

        #Dependency Name
        [Parameter(Mandatory=$true)]
        [string]$Name = "Update mailbox",
        [string]$CommandName = $name,
        [string]$DependencyTypeName = $name,

        #HTTP result code
        [bool]$Success = $true, 
        [ValidateRange(0,999)]
        [int]$ResultCode = 200, 

        #The timestamp for the event; defaults to current date/time
        $Timestamp = (Get-Date), 
        #The AppInsights Client object to use.
        [Parameter(Mandatory=$false)]
        [Microsoft.ApplicationInsights.TelemetryClient] $Client = $Global:AISingleton.Client,
        #Type of dependecy 
        [ValidateSet("HTTP", "SQL", "Other")]
        [string]$DependencyKind = "Other",


        #Directly flush the AI events to the service
        [switch] $Flush
    )
    Begin { 
        #Check for a specified AI client
        if ($Client -eq $null) {
            throw [System.Management.Automation.PSArgumentNullException]::new($script:ErrNoClient)
        }
    } 
    Process { 

        #check if a timespan has been provided 
        if ( $StopWatch -eq $null -and $TimeSpan -eq $null ) {
            Write-Warning "No time provided for dependency"
        } 
        #get a dependecy object 
        $TelDependency= [Microsoft.ApplicationInsights.DataContracts.DependencyTelemetry]::new()
        # not HTTP or SQL so Other 
        $TelDependency.DependencyKind = $DependencyKind
        # UP to Now.
        $TelDependency.Timestamp = $timestamp

        #Add information 
        $TelDependency.Name =  $Name
        $TelDependency.CommandName = $CommandName
        $TelDependency.DependencyTypeName = $DependencyTypeName

        $TelDependency.Success = $Success
        $TelDependency.ResultCode = $ResultCode
    
        if ($TimeSpan ) { 
            $TelDependency.Duration = $TimeSpan
        } else { 
            $TelDependency.Duration = $StopWatch.Elapsed
        }

        #Send it 
        $Client.TrackDependency($TelDependency)
        if ($Flush) { 
            $client.Flush()
        }

    }
}



