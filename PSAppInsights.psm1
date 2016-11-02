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
                    Flush-AIClient -Client $Global:AISingleton.Client
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
    Flush the Application Insights Queue to the AI Service
    
#>
function Push-AIClient
{
    [CmdletBinding()]
    [Alias("Flush-AIClient")]
    [Alias("Flush-AISession")]  # Depricated 

    Param
    (
        #The AppInsights Client object to use.
        [Parameter(Mandatory=$false)]
        [Microsoft.ApplicationInsights.TelemetryClient] $Client = $Global:AISingleton.Client
    )
    $client.Flush()
}

