<#
.Synopsis
   Send a Custom Event to Application Insights.
   A custom event is a data point that you can display both in in Metrics Explorer as an aggregated count, 
   and also as individual occurrences in Diagnostic Search 
.EXAMPLE
   Example of how to use this cmdlet
#>
function Send-AIPageView
{
    [CmdletBinding()]
    #[OutputType([int])]
    Param
    (
        # The Name of the Page
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [string] $PageName,
        
        #The URL of the Page
        [string] $URL = $null,
        
        #Map of string to string: Additional data used to filter pages in the portal.
        $Properties = $null,
        #Map of string to number: Metrics associated with this page, displayed in Metrics Explorer on the portal. 
        $Metrics = $null,

        # Duration In Milliseconds #ToDo / Change to Timeinterval ?
        [int] $Duration,

        #The AppInsights Client object to use.
        [Parameter(Mandatory=$false)]
        [Microsoft.ApplicationInsights.TelemetryClient] $Client = $Global:AISingleton.Client,
        
        #include call stack  information (Default)
        [switch] $NoStack,
        #The number of Stacklevels to go up 
        [int]$StackWalk = 0,

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

    #$durationInMilliseconds

    $client.trackPageView($PageName, $URL , $Properties, $Metrics, $duration);
  

      <#
      void TrackPageView(string name)
      void TrackPageView(Microsoft.ApplicationInsights.DataContracts.PageViewTelemetry telemetry)
    #>    
    
    if ($Flush) { 
        $client.Flush()
    }
}


