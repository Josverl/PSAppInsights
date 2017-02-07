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
    #QuickPulse aka Live Metrics Stream
    QuickPulse = $null
    #Stack of current Operations
    Operations = [System.Collections.Stack]::new()
}

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
        [Alias("Key")]
        $InstrumentationKey,
        [string]$SessionID = (New-Guid), 
        [string]$OperationID = (New-Guid), #? Base 64 encoded GUID ?
        #Version of the application or Component
        $Version,
        # Set to indicate messages sent from or during a test 
        [string]$Synthetic = $null,

        #Set of initializers - Default: Operation Correlation is enabled 
        [Alias("Init")]
        [ValidateSet('Domain','Device','Operation','Dependency')]
        [String[]] $Initializer = @(), 
        
        #Allow PII in Traces 
        [switch]$AllowPII,

        #Send AI traces via Fiddler for debugging
        [switch]$Fiddler

    )


    Process
    {
        try { 
            Write-Verbose "create Telemetry client"

            # This is a singleton that controls all New AI Client sessions for this process from this moment 
            [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.InstrumentationKey = $InstrumentationKey
            [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.DisableTelemetry = $false

            #optionally add Fiddler for debugging
            if ($fiddler) { 
                [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.TelemetryChannel.EndpointAddress = 'http://localhost:8888/v2/track'
            }
            
            $Global:AISingleton.Configuration = [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active
            # Start the initialisers specified
            if ($Initializer.Contains('Operation')) {
                #Initializer for operation correlation 
                $OpInit = [Microsoft.ApplicationInsights.Extensibility.OperationCorrelationTelemetryInitializer]::new()
                $Global:AISingleton.Configuration.TelemetryInitializers.Add($OpInit)
            }
            #Add domain initialiser to add domain and machine info 
            if ($Initializer.Contains('Domain')) {
                $DomInit = [Microsoft.ApplicationInsights.WindowsServer.DomainNameRoleInstanceTelemetryInitializer]::new()
                $Global:AISingleton.Configuration.TelemetryInitializers.Add($DomInit)
            }
            #Add device initiliser to add client info 
            if ($Initializer.Contains('Device')) {
                $DeviceInit = [Microsoft.ApplicationInsights.WindowsServer.DeviceTelemetryInitializer]::new()
                $Global:AISingleton.Configuration.TelemetryInitializers.Add($DeviceInit)
            }

            #Add dependency collector to (automatically ?) measure dependencies 
            if ($Initializer.Contains('Dependency')) {
                $Dependency = [Microsoft.ApplicationInsights.DependencyCollector.DependencyTrackingTelemetryModule]::new();
                $TelemetryModules = [Microsoft.ApplicationInsights.Extensibility.Implementation.TelemetryModules]::Instance;
                $TelemetryModules.Modules.Add($Dependency);
            }

            #Now that they are added, they still need to be initialised
            #Lets do it
            $Global:AISingleton.Configuration.TelemetryInitializers | 
                Where-Object {$_ -is 'Microsoft.ApplicationInsights.Extensibility.ITelemetryModule'} |
                ForEach-Object { $_.Initialize($Global:AISingleton.Configuration); }
		    $Global:AISingleton.Configuration.TelemetryProcessorChain.TelemetryProcessors |
                 Where-Object {$_ -is 'Microsoft.ApplicationInsights.Extensibility.ITelemetryModule'} |
                  ForEach-Object { $_.Initialize($Global:AISingleton.Configuration); }
            $TelemetryModules = [Microsoft.ApplicationInsights.Extensibility.Implementation.TelemetryModules]::Instance;
            $TelemetryModules.Modules | 
                Where-Object {$_ -is 'Microsoft.ApplicationInsights.Extensibility.ITelemetryModule'} |
                ForEach-Object { $_.Initialize($Global:AISingleton.Configuration); }
            #Time to start the client 
            $client = [Microsoft.ApplicationInsights.TelemetryClient]::new($Global:AISingleton.Configuration)

            if ($client) { 
                Write-Verbose "Add Key, Session.id and Operation.id"
                
                $client.InstrumentationKey = $InstrumentationKey
                $client.Context.Session.Id = $SessionID
                #Operation : A generated value that correlates different events, so that you can find "Related items"
                $client.Context.Operation.Id = $OperationID

                #do some standard init on the context 
                # set properties such as TelemetryClient.Context.User.Id to track users and sessions, 
                # or TelemetryClient.Context.Device.Id to identify the machine. 
                # This information is attached to all events sent by the instance.
                
                Write-Verbose "Add device.OS and User Agent"
                #OS cannot be read in Azure automation, handle gracefully
                $OS = Get-CimInstance -ClassName 'Win32_OperatingSystem' -ErrorAction SilentlyContinue
                if ($OS) {
                    $client.Context.Device.OperatingSystem = $OS.version
                }
                $client.Context.User.UserAgent = $Host.Name

                if ($AllowPII) {
                    Write-Verbose "Add PII user and computer information"

                    #Only if Explicitly noted
                    $client.Context.Device.Id = $env:COMPUTERNAME 
                    $client.Context.User.Id = $env:USERNAME 
                } else { 
                    Write-Verbose "Add NON-PII user and computer identifiers"
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

<#
.Synopsis
    Stop and flush the App Insights telemetry client, and disables the per-process config.
.EXAMPLE
    Stop-AIClient 
.EXAMPLE
    Stop-AIClient -Client $TelemetryClient
#>
function Stop-AIClient
{
    [CmdletBinding()]
    [OutputType([void])]
    Param
    (
        # The Telemetry client to flush and stop, defaults to the
        [Parameter(Mandatory=$false)]
        $Client = $Global:AISingleton.Client
    )
    if ($Client) {
        Write-Verbose "Stopping telemetry client"
        Flush-AIClient -Client $Client
        #And disable telemetry for 
        [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.DisableTelemetry = $true
    } else {
        Write-Warning "No AppInsights telemetry client active"
    }
}