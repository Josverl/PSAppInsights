<#
    PowerShell App Insights Module
    V0.7.1
    Application Insight Tracing to Powershell Scripts and Modules

Documentation : 
    Ref .Net : https://msdn.microsoft.com/en-us/library/microsoft.applicationinsights.aspx
    Ref JS   : https://github.com/Microsoft/ApplicationInsights-JS/blob/master/API-reference.md
#>

$Global:AISingleton = @{
    ErrNoClient = "Client - No Application Insights Client specified or initialized."
    Configuration = $null    
    #The current AI Client
    Client = $null
    #The Perfmon Collector
    PerformanceCollector = $null
    #Stack of current Operations
    Operations = [System.Collections.Stack]::new()
}

$script:ErrNoClient = "Client - No Application Insights Client specified or initialized."


<#
.Synopsis
   Start a new AI Client 
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet

#>
function New-AIClient
{
    [CmdletBinding()]
    [Alias('New-AISession')]
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
        #Version of the application or Component
        $Version,
        # Set to indicate messages sent from or during a test 
        [string]$Synthetic = $null,

        #Set of initializers - Default: Operation Correlation is enabled 
        [Alias("Initializer")]
        [ValidateSet('Domain','Device','Operation')]
        [String[]] $Init = @(), 
        
        #Allow PII in Traces 
        [switch]$AllowPII,

        #Send AI traces via Fiddler for debugging
        [switch]$Fiddler

    )


    Process
    {
        try { 
            Write-Verbose "create Telemetry client"

            # Is this a singleton that controls all New AI Client sessions from this moment 
            [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.InstrumentationKey = $key

            #optionally add Fiddler for debugging
            if ($fiddler) { 
                [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.TelemetryChannel.EndpointAddress = 'http://localhost:8888/v2/track'
            }
            
            $Global:AISingleton.Configuration = [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active

            if ($Init.Contains('Operation')) {
                #Initializer for operation correlation 
                $OpInit = [Microsoft.ApplicationInsights.Extensibility.OperationCorrelationTelemetryInitializer]::new()
                $Global:AISingleton.Configuration.TelemetryInitializers.Add($OpInit)
            }
            if ($Init.Contains('Domain')) {
                $DomInit = [Microsoft.ApplicationInsights.WindowsServer.DomainNameRoleInstanceTelemetryInitializer]::new()
                $Global:AISingleton.Configuration.TelemetryInitializers.Add($DomInit)
            }

            if ($Init.Contains('Device')) {
                $DeviceInit = [Microsoft.ApplicationInsights.WindowsServer.DeviceTelemetryInitializer]::new()
                $Global:AISingleton.Configuration.TelemetryInitializers.Add($DeviceInit)
            }
            $client = [Microsoft.ApplicationInsights.TelemetryClient]::new($Global:AISingleton.Configuration)

#            $client = New-Object Microsoft.ApplicationInsights.TelemetryClient  
            if ($client) { 
                Write-Verbose "Add Key, Session.id and Operation.id"
                
                $client.InstrumentationKey = $Key
                $client.Context.Session.Id = $SessionID
                #Operation : A generated value that correlates different events, so that you can find "Related items"
                $client.Context.Operation.Id = $OperationID

                #do some standard init on the context 
                # set properties such as TelemetryClient.Context.User.Id to track users and sessions, 
                # or TelemetryClient.Context.Device.Id to identify the machine. 
                # This information is attached to all events sent by the instance.

                Write-Verbose "Add device.OS and User Agent"
                $client.Context.Device.OperatingSystem = (Get-CimInstance Win32_OperatingSystem).version
                $client.Context.User.UserAgent = $Host.Name

                if ($AllowPII) {
                    Write-Verbose "Add PII user and computer"

                    #Only if Explicitly noted
                    $client.Context.Device.Id = $env:COMPUTERNAME 
                    $client.Context.User.Id = $env:USERNAME 
                } else { 
                    Write-Verbose "Add NON-PII user and computer"
                    #Default to NON-PII 
                    $client.Context.Device.Id = (Get-StringHash -String $env:COMPUTERNAME -HashType MD5).hash 
                    $client.Context.User.Id = (Get-StringHash -String $env:USERNAME -HashType MD5).hash  
                }
                if ($Global:AISingleton.Client -ne $null ) {
                    Write-Verbose "replacing active telemetry client"
                    Flush-AISession -Client $Global:AISingleton.Client
                    $Global:AISingleton.Client = $null
                } 
                #Save client in Global for re-use when not specified 
                $Global:AISingleton.Client = $client

                if ($Version ) {
                    write-verbose "use specified version"
                    $client.Context.Component.Version = [string]($version)
                } else {
                    write-verbose "retrieve version of calling script or module."
                    $client.Context.Component.Version = [string](getCallerVersion -level 2)
                }

                #Indicate actual / Synthethic events
                $Global:AISingleton.Client.Context.Operation.SyntheticSource = $Synthetic

                return $client 
            } else { 
                Throw "Could not create ApplicationInsights Client"
            }
        } catch {
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
    [Alias("Flush-AISession")]

    Param
    (
        #The AppInsights Client object to use.
        [Parameter(Mandatory=$false)]
        [Microsoft.ApplicationInsights.TelemetryClient] $Client = $Global:AISingleton.Client
    )
    $client.Flush()
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
        
        #Severity, Defaults to Information
        [Parameter()]
        [Alias("Severity")]
        $SeverityLevel = [Microsoft.ApplicationInsights.DataContracts.SeverityLevel]::Information, 
        #any custom Properties that need to be added to the trace 
        [Hashtable]$Properties,


        #include call stack  information (Default)
        [switch] $NoStack,
        
        #The AppInsights Client object to use.
        [Parameter(Mandatory=$false)]
        [Microsoft.ApplicationInsights.TelemetryClient] $Client = $Global:AISingleton.Client,

        #Directly flush the AI events to the service
        [switch] $Flush
    )
    #Check for a specified AI client
    if ($Client -eq $null) {
        throw [System.Management.Automation.PSArgumentNullException]::new($script:ErrNoClient)
    }
    #Setup dictionaries     
    $dictProperties = New-Object 'system.collections.generic.dictionary[[string],[string]]'

    #Send the callstack
    if ($NoStack -eq $false) { 
        $dictProperties = getCallerInfo -level 2
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
        #The AppInsights Client object to use.
        [Parameter(Mandatory=$false)]
        [Microsoft.ApplicationInsights.TelemetryClient] $Client = $Global:AISingleton.Client,
       
        #any custom Properties that need to be added to the event 
        [Hashtable]$Properties,
        #any custom metrics that need to be added to the event 
        [Hashtable]$Metrics,
        #include call stack  information (Default)
        [switch] $NoStack,
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
    if ($NoStack -eq $false) { 
        $dictProperties = getCallerInfo -level 2
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

        #any custom Properties that need to be added to the event 
        [Hashtable]$Properties,

        #The AppInsights Client object to use.
        [Parameter(Mandatory=$false)]
        [Microsoft.ApplicationInsights.TelemetryClient] $Client = $Global:AISingleton.Client,

        #include call stack  information (Default)
        [switch] $NoStack,

        #Directly flush the AI events to the service
        [switch] $Flush

    )
    #Check for a specified AI client
    if ($Client -eq $null) {
        throw [System.Management.Automation.PSArgumentNullException]::new($script:ErrNoClient)
    }
    #Setup dictionaries     
    $dictProperties = New-Object 'system.collections.generic.dictionary[[string],[string]]'

    #Send the callstack
    if ($NoStack -eq $false) { 
        $dictProperties = getCallerInfo -level 2
    }
    #Add the Properties to Dictionary
    if ($Properties) { 
        foreach ($h in $Properties.GetEnumerator() ) {
            $dictProperties.Add($h.Name, $h.Value)
        }
    }

    $client.trackMetric($Metric, $Value, $dictProperties);

    if ($Flush) { 
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
        [Parameter(Mandatory=$false)]
        [Microsoft.ApplicationInsights.TelemetryClient] $Client = $Global:AISingleton.Client,
        
        #include call stack  information (Default)
        [switch] $NoStack,

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
        $dictProperties = getCallerInfo -level 2
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

    $client.TrackEvent($AIExeption)

    #$client.TrackException($Exception) 
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
    if ($NoStack -eq $false) { 
        $dictProperties = getCallerInfo -level 2
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

<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
#>
function start-AIPerformanceCollector
{
    [CmdletBinding()]
    Param(
        # The App Insights Key 
        [Parameter(Mandatory=$true)] 
        $Key,
        #Process Counters of the powershell process to collect 
        [string[]]
        $ProcessCounters = @( 'Handle Count', 'Working Set' )
        # @todo Set to suppress sending messages in a test environment
        # [string]$Synthetic

    )
    if ($Global:AISingleton.PerformanceCollector) { Stop-AIPerformanceCollector }
    Write-Verbose "Create AI Performance Collector Instance"
    $Global:AISingleton.PerformanceCollector = New-Object  Microsoft.ApplicationInsights.Extensibility.PerfCounterCollector.PerformanceCollectorModule

    Write-Verbose "Add ??APP_WIN32_PROC?? performance counters"
    #$ProcessName =  "??{0}??" -f ([System.Diagnostics.Process]::GetCurrentProcess()).ProcessName
    $ProcessName =  ([System.Diagnostics.Process]::GetCurrentProcess()).ProcessName 
    foreach ( $c in $ProcessCounters ) { 
        $Counter = "\Process($ProcessName)\$c"
        $CollectionRequest = New-Object  Microsoft.ApplicationInsights.Extensibility.PerfCounterCollector.PerformanceCounterCollectionRequest -ArgumentList $Counter, $c
        $Global:AISingleton.PerformanceCollector.Counters.Add( $CollectionRequest)
    } 
    #Add Processes
    $CollectionRequest = New-Object  Microsoft.ApplicationInsights.Extensibility.PerfCounterCollector.PerformanceCounterCollectionRequest -ArgumentList "\Objects\Processes", "Processes"
    $Global:AISingleton.PerformanceCollector.Counters.Add( $CollectionRequest)

<# Debug 
    [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.TelemetryChannel.EndpointAddress = 'http://localhost:8888/v2/track'
#>    Write-Verbose "Initialize"
    [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.InstrumentationKey = $key
    $Global:AISingleton.PerformanceCollector.Initialize( [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active )}

function Stop-AIPerformanceCollector
{
    [CmdletBinding()]
    Param()

    if ($Global:AISingleton.PerformanceCollector) {
        Write-Verbose "Stoping Performance counter collection"
        $Global:AISingleton.PerformanceCollector.Dispose()
        $Global:AISingleton.PerformanceCollector = $null
    }
}



<#------------------------------------------------------------------------------------------------------------------
    Helper Functions 
--------------------------------------------------------------------------------------------------------------------#>


<#
 helper function 
 Get-StringHash Credits : Jeff Wouters
 ref: http://jeffwouters.nl/index.php/2013/12/Get-StringHash-for-files-or-strings/
#>

function Get-StringHash {
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


<#
    Helper function to get the script and the line number of the calling function
#>
function getCallerInfo ($level = 2)
{
[CmdletBinding()]
    $dict = New-Object 'system.collections.generic.dictionary[[string],[string]]'
    try { 
        #Get the caller info
        $caller = (Get-PSCallStack)[$level] 
        #get only the script name
        $ScriptName = '<unknown>'
        if ($caller.Location) {
            $ScriptName = ($caller.Location).Split(':')[0]
        }

        $dict.Add('ScriptName', $ScriptName)
        $dict.Add('ScriptLineNumber', $caller.ScriptLineNumber)
        $dict.Add('Command', $caller.Command)
        $dict.Add('FunctionName', $caller.FunctionName)

        return $dict

    } catch { return $null}
}

<#
    Helper function to get the calling script or module version#>
function getCallerVersion 
{
[CmdletBinding()]
param(
    [int]$level = 2
)
    try { 
        #Get the caller info
        $caller = (Get-PSCallStack)[$level] 
        #get only the script name
        $ScriptName = '<unknown>'
        if ($caller.Location) {
            $ScriptName = ($caller.Location).Split(':')[0]
        }

        $dict.Add('ScriptName', $ScriptName)
        $dict.Add('ScriptLineNumber', $caller.ScriptLineNumber)
        $dict.Add('Command', $caller.Command)
        $dict.Add('FunctionName', $caller.FunctionName)

        return $dict

    } catch { return $null}
}

<#
    Helper function to get the calling script or module version
#>
function getCallerVersion 
{
[CmdletBinding()]
param(
    #Get version from X levels up in the call stack
    [int]$level = 1
)
    Write-Verbose "getCallerVersion -level $level"
    [Version]$V = $null
    try { 
        #Get the caller info
        $caller = (Get-PSCallStack)[$level] 
        #if script
        if ( -NOT [string]::IsNullOrEmpty( $caller.ScriptName)){
            $info = Test-ScriptFileInfo -Path $caller.ScriptName -ErrorAction SilentlyContinue
            if ( $info ) {
                $v = $info.Version
                Write-Verbose "getCallerVersion found script version $v"
                return $v
            }
        }       
    } catch { }
    Try {
        #try module info based on the name, but with a psd1 extention
        $Filename = [System.IO.Path]::ChangeExtension( $caller.ScriptName, 'psd1')
        $info = Test-ModuleManifest -Path $Filename -ErrorAction SilentlyContinue
        if ( $info ) {
            $v = $info.Version
            Write-Verbose "getCallerVersion found Module version $v"
            return $v
            break;
        }
    } catch {} # Continue 

    try {
        #try to find a version from the path and folder names 
        $Folders= @( $Filename.Split('\') )
        $found = $false
        foreach( $f in $Folders ) {
            Try { $V = [version]$f ; $found = $true} 
            catch {}
        }
        if ($found) {
            #return last found version
            Write-Verbose "getCallerVersion found Folder version $v"
            return $v
        }
    } catch {
        Write-Verbose "getCallerVersion no version found"         
        return $v
    }
    Write-Verbose "no version found"
    return $v
}

