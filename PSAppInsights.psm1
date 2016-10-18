<#
    Add Azure Application Insight Tracing to Powershell Scripts and Modules


    Ref: https://github.com/Microsoft/ApplicationInsights-JS/blob/master/API-reference.md
#>

<#
.Synopsis
   Start a new AI Session
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet

#>
function New-AISession
{
    [CmdletBinding()]
    [OutputType([Microsoft.ApplicationInsights.TelemetryClient])]
    Param
    (
        # The Instrumentation Key for Application Analytics
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Key ,
        [string]$SessionID = (New-Guid), 
        [string]$OperationID = (New-Guid), 
        # Set to suppress sending messages in a test environment
        [switch]$Synthetic 
    )

    Process
    {
        $client = New-Object Microsoft.ApplicationInsights.TelemetryClient  
        if ($client) { 
            $client.InstrumentationKey = $Key
            $client.Context.Session.Id = $SessionID

            #Operation : A generated value that correlates different events, so that you can find "Related items"
            $client.Context.Operation.Id = $OperationID

            #do some standard init on the context 
            # set properties such as TelemetryClient.Context.User.Id to track users and sessions, 
            # or TelemetryClient.Context.Device.Id to identify the machine. 
            # This information is attached to all events sent by the instance.

            $client.Context.Device.OperatingSystem = (Get-CimInstance Win32_OperatingSystem).version
            $client.Context.Device.Id = $env:COMPUTERNAME #TODO : Need to hash this


            $client.Context.User.UserAgent = $Host.Name
            $client.Context.User.Id = $env:USERNAME #TODO : Need to hash this

            return $client 
        } else { 
            Throw "Could not create ApplicationInsights Client"
        }
    }
}


<# Initializers 
The Application Insights .NET SDK consists of a number of NuGet packages. 
The core package provides the API for sending telemetry to the Application Insights. 
By adjusting the configuration file, you can enable or disable telemetry modules and initializers, and set parameters for some of them.
The configuration file is named ApplicationInsights.config or ApplicationInsights.xml, depending on the type of your application. 


DeviceTelemetryInitializer updates the following properties of the Device context for all telemetry items. 
- Type is set to "PC"
- Id is set to the domain name of the computer where the web application is running.
- OemName is set to the value extracted from the Win32_ComputerSystem.Manufacturer field using WMI.
- Model is set to the value extracted from the Win32_ComputerSystem.Model field using WMI.
- NetworkType is set to the value extracted from the NetworkInterface.
- Language is set to the name of the CurrentCulture.



#>



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

        #The AppInsights Client object to use.
        [Parameter(Mandatory=$true)]
        [Microsoft.ApplicationInsights.TelemetryClient] $Client,
        
        #Directly flush the AI events to the service
        [switch] $flush

    )
    $client.TrackTrace($Message)
    
    if ($flush) { 
        $client.Flush()
    }
}


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
        [string] $Message,

        #The AppInsights Client object to use.
        [Parameter(Mandatory=$true)]
        [Microsoft.ApplicationInsights.TelemetryClient] $Client,
        
        #Directly flush the AI events to the service
        [switch] $flush

    )
    
    $client.TrackEvent($Message)

    <#
    void TrackEvent(string eventName, System.Collections.Generic.IDictionary[string,string] properties, System.Collections.Generic.IDictionary[string
    ,double] metrics)
    void TrackEvent(Microsoft.ApplicationInsights.DataContracts.EventTelemetry telemetry)
    #>    
    
    if ($flush) { 
        $client.Flush()
    }
}




<#
.Synopsis


   name
A string that identifies the metric. In the portal, you can select metrics for display by name.
average
Either a single measurement, or the average of several measurements. Should be >=0 to be correctly displayed.
sampleCount
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

        #The AppInsights Client object to use.
        [Parameter(Mandatory=$true)]
        [Microsoft.ApplicationInsights.TelemetryClient] $Client,
        
        #Directly flush the AI events to the service
        [switch] $flush

    )
    $client.trackMetric($Metric, $Value);
  
      <#
    void TrackMetric(string name, double value, System.Collections.Generic.IDictionary[string,string] properties)
    void TrackMetric(Microsoft.ApplicationInsights.DataContracts.MetricTelemetry telemetry)
    #>    
    
    if ($flush) { 
        $client.Flush()
    }
}



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

        #Map of string to string: Additional data used to filter pages in the portal.
        $Properties = $null,
        #Map of string to number: Metrics associated with this page, displayed in Metrics Explorer on the portal. 
        $Metrics = $null,

        #The AppInsights Client object to use.
        [Parameter(Mandatory=$true)]
        [Microsoft.ApplicationInsights.TelemetryClient] $Client,
        
        #Directly flush the AI events to the service
        [switch] $flush

    )
    
    $client.TrackEvent($Event)

    <#
    void TrackEvent(string eventName, 
                    System.Collections.Generic.IDictionary[string,string] properties, 
                    System.Collections.Generic.IDictionary[string,double] metrics)
    #>    
    
    if ($flush) { 
        $client.Flush()
    }
}





<#
Dependency Tracking
Dependency tracking collects telemetry about calls your app makes to databases and external services and databases
#>





<#
.Synopsis
   Flush the Application Insights Queue to the Service
#>
function Flush-AITrace
{
    [CmdletBinding()]
    Param
    (
        #The AppInsights Client object to use.
        [Parameter(Mandatory=$true)]
        [Microsoft.ApplicationInsights.TelemetryClient] $Client
    )
    $client.Flush()
}


<#
.Synopsis


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
        [Parameter(Mandatory=$true)]
        [Microsoft.ApplicationInsights.TelemetryClient] $Client,
        
        #Directly flush the AI events to the service
        [switch] $flush

    )
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
    
    if ($flush) { 
        $client.Flush()
    }
}

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

        # Duration In Milliseconds
        [int] $Duration,

        #The AppInsights Client object to use.
        [Parameter(Mandatory=$true)]
        [Microsoft.ApplicationInsights.TelemetryClient] $Client,
        
        #Directly flush the AI events to the service
        [switch] $flush

    )
    #$durationInMilliseconds

    $client.trackPageView($PageName, $URL , $Properties, $Metrics, $duration);
  

      <#
      void TrackPageView(string name)
      void TrackPageView(Microsoft.ApplicationInsights.DataContracts.PageViewTelemetry telemetry)
    #>    
    
    if ($flush) { 
        $client.Flush()
    }
}
