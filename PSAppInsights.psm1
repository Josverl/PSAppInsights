<#
    PowerShell App Insights Module
    V0.3
    Application Insight Tracing to Powershell Scripts and Modules

Documentation : 
    Ref .Net : https://msdn.microsoft.com/en-us/library/microsoft.applicationinsights.aspx
    Ref JS   : https://github.com/Microsoft/ApplicationInsights-JS/blob/master/API-reference.md
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
        [switch]$Synthetic,
        
        #Allow PII in Traces 
        [switch]$AllowPII 
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


            $client.Context.User.UserAgent = $Host.Name
            if ($AllowPII) {
                #Only if Explicitly noted
                $client.Context.Device.Id = $env:COMPUTERNAME 
                $client.Context.User.Id = $env:USERNAME 
            } else { 
                #Default to NON-PII 
                $client.Context.Device.Id = (Get-Hash -String $env:COMPUTERNAME -HashType MD5).hash 
                $client.Context.User.Id = (Get-Hash -String $env:USERNAME -HashType MD5).hash  
            }

            return $client 
        } else { 
            Throw "Could not create ApplicationInsights Client"
        }
    }
}


<#
.Synopsis
   Flush the Application Insights Queue to the Service
   TODO Add Alias FLUSH ?
#>
function Push-AISession
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
 Get-Hash Credits : Jeff Wouters
 ref: http://jeffwouters.nl/index.php/2013/12/get-hash-for-files-or-strings/
#>

function Get-Hash {
    [cmdletbinding()]
    param (
        [parameter(mandatory=$false,parametersetname="String")]$String,
        [parameter(mandatory=$false,parametersetname="File")]$File,
        [parameter(mandatory=$false,parametersetname="String")]
        [validateset("MD5","SHA1","SHA256","SHA384","SHA512","RIPEMD160")]
        [parameter(mandatory=$false,parametersetname="File")]
        [validateset("MD5","SHA1","SHA256","SHA384","SHA512","RIPEMD160")]
        [string]$HashType = "MD5"
    )
    switch ($PsCmdlet.ParameterSetName) { 
        "String" {
            $StringBuilder = New-Object System.Text.StringBuilder 
            [System.Security.Cryptography.HashAlgorithm]::Create($HashType).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String))| ForEach-Object {
                [Void]$StringBuilder.Append($_.ToString("x2")) 
            }
            $Object = New-Object -TypeName PSObject
            $Object | Add-Member -MemberType NoteProperty -Name 'String' -value $String
            $Object | Add-Member -MemberType NoteProperty -Name 'HashType' -Value $HashType
            $Object | Add-Member -MemberType NoteProperty -Name 'Hash' -Value $StringBuilder.ToString()
            $Object
        } 
        "File" {
            $StringBuilder = New-Object System.Text.StringBuilder
            $InputStream = New-Object System.IO.FileStream($File,[System.IO.FileMode]::Open)
            switch ($HashType) {
                "MD5" { $Provider = New-Object System.Security.Cryptography.MD5CryptoServiceProvider }
                "SHA1" { $Provider = New-Object System.Security.Cryptography.SHA1CryptoServiceProvider }
                "SHA256" { $Provider = New-Object System.Security.Cryptography.SHA256CryptoServiceProvider }
                "SHA384" { $Provider = New-Object System.Security.Cryptography.SHA384CryptoServiceProvider }
                "SHA512" { $Provider = New-Object System.Security.Cryptography.SHA512CryptoServiceProvider }
                "RIPEMD160" { $Provider = New-Object System.Security.Cryptography.CryptoServiceProvider }
            }
            $Provider.ComputeHash($InputStream) | Foreach-Object { [void]$StringBuilder.Append($_.ToString("X2")) }
            $InputStream.Close()
            $Object = New-Object -TypeName PSObject
            $Object | Add-Member -MemberType NoteProperty -Name 'File' -value $File
            $Object | Add-Member -MemberType NoteProperty -Name 'HashType' -Value $HashType
            $Object | Add-Member -MemberType NoteProperty -Name 'Hash' -Value $StringBuilder.ToString()
            $Object           
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

    if ($todo ) { 

        $telemetryException = New-Object "Microsoft.ApplicationInsights.DataContracts.ExceptionTelemetry"  
        $telemetryException.Exception = $_.Exception  

        $dictProperties = New-Object 'system.collections.generic.dictionary[[string],[string]]'
        $dictMetrics = New-Object 'system.collections.generic.dictionary[[string],[double]]'
    
        $telemetryException.Metrics = $dictMetrics ## FAILS:: ReadOnly 

        $telemetryException.SeverityLevel = 4   # Low to High 
    } 


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
