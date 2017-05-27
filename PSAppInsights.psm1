<#
    PowerShell App Insights Module
    V0.9.1
    Application Insight Tracing to Powershell Scripts and Modules

Documentation : 
    Ref .Net : https://msdn.microsoft.com/en-us/library/microsoft.applicationinsights.aspx
    Ref JS   : https://github.com/Microsoft/ApplicationInsights-JS/blob/master/API-reference.md
#>

if ( $Global:AISingleton -eq $null ) {

#Only initialize on the first load of the module 
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
} 
<#
.Synopsis
   Start a new Application Insights Client to Log events and timings to AI
.DESCRIPTION
   Long description
.EXAMPLE
   $C1 = New-AIClient -InstrumentationKey $key

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
        [String]$InstrumentationKey,
        #An Identifier to use for this session
        [string]$SessionID = ( New-Guid), 
        #Operation, by default the Scriptname will be used
        [string]$OperationID , # Use the scriptname if it can be found
        #Version of the application or Component, defaults to retrieving theversion from the script
        $Version,
        # Set to indicate messages sent from or during a test 
        [string]$Synthetic = $null,

        #Set of initializers - Default: Operation Correlation is enabled 
        [Alias("Init")]
        [ValidateSet('Domain','Device','Operation','Dependency')]
        [String[]] $Initializer = @(), 
        
        #Allow Personal Identifiable information such as Computernames and current user name to be sent in the Traces 
        [Alias("PII")]
        [switch]$AllowPII,

        #Send through Fiddler for debugging
        [switch]$Fiddler,
        
        #When developer mode is True, sends telemetry to Application Insights immediately during the entire lifetime of the application
        [switch]$DeveloperMode,

        # Sets the maximum telemetry batching interval in seconds. Once the interval expires, sends the accumulated telemetry items for transmission.
        [ValidateRange(1, 1440)] #Up to day should be sufficient
        $SendingInterval = 0 
    )

    Process
    {
        if ( [String]::IsNullOrEmpty($OperationID) ){
        #Find a sensible toplevel Operation ID
            #Get the topmost caller's information
            $TopInfo = getCallerInfo -level (Get-PSCallStack).Length
            if     ($TopInfo.Script)                      { $OperationID = $TopInfo.Script } 
            else { 
                if ($TopInfo.Command -ne '<ScriptBlock>') { $OperationID = $TopInfo.Command } 
                else { 
                    if ($TopInfo.FunctionName -ne '<ScriptBlock>') { $OperationID = $TopInfo.FunctionName }
                    # Otherwise AI will set a GUID 
                }
            }
        }
        
        try { 
            Write-Verbose "create Telemetry client"
            # This is a singleton that controls all New AI Client sessions for this process from this moment 
            [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.InstrumentationKey = $InstrumentationKey
            [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.DisableTelemetry = $false

            #optionally add Fiddler for debugging
            if ($fiddler) { 
                [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.TelemetryChannel.EndpointAddress = 'http://localhost:8888/v2/track'
            }

            #Activate/deactivate developermode 
            if ($DeveloperMode) {
                Write-Verbose "Set DeveloperMode" 
                [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.TelemetryChannel.DeveloperMode = $true
            } else {
                Write-Verbose "Set DeveloperMode off" 
                [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.TelemetryChannel.DeveloperMode = $false
            }

            If ($SendingInterval -ne 0)
            {        
                Write-Verbose "Set Bufferdelay to $SendingInterval seconds." 
                [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.TelemetryChannel.SendingInterval = New-TimeSpan -Seconds $SendingInterval
            }

            $Global:AISingleton.Configuration = [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active
            #----------------------
            # Initialisers 
            #   - A context initializer will only be called once per TelemetryClient instance
            #   - A Telemetry Initialiser will be called for each Telemetry 'Message'
            # ---------------------
            # ITelemetryProcessor and ITelemetryInitializer
            # What's the difference between telemetry processors and telemetry initializers?
            # There are some overlaps in what you can do with them: both can be used to add properties to telemetry.
            #  - TelemetryInitializers always run before TelemetryProcessors.
            #  - TelemetryProcessors allow you to completely replace or discard a telemetry item.
            #  - TelemetryProcessors don't process performance counter telemetry
            #----------------------
            #Context Initialisers 
            #----------------------
            #Add domain initialiser to add domain and machine info 
            if ($Initializer.Contains('Domain')) {
                Try { 
                    Write-Verbose "Add initializer- domain and machine info" 
                    $DomInit = [Microsoft.ApplicationInsights.WindowsServer.DomainNameRoleInstanceTelemetryInitializer]::new()
                    $Global:AISingleton.Configuration.TelemetryInitializers.Add($DomInit)
                } catch { 
                    #Warn but do not abort
                    Write-Warning "Could not add the Domain initialiser"
                }
            }
            #Add device initialiser to add client info 
            if ($Initializer.Contains('Device')) {
                
                #If on AzureAutomation, just report Azure automation
                If ($false) {
                    Write-Verbose "TODO Add Azure Automation- device info"
                    
                }else {
                    Try { 
                        Write-Verbose "Add initializer- device info"
                        $DeviceInit = [Microsoft.ApplicationInsights.WindowsServer.DeviceTelemetryInitializer]::new()
                        $Global:AISingleton.Configuration.TelemetryInitializers.Add($DeviceInit)
                    } catch { 
                        #Warn but do not abort
                        Write-Warning "Could not add the Device initialiser"
                    }

                }
            }
            #----------------------
            #Telemetry Initialisers 
            #----------------------
            # Add  the initialisers specified
            # If you provide a telemetry initializer, it is called whenever any of the Track*() (ai native) methods is called.
            # This includes methods called by the standard telemetry modules. By convention, these modules 
            # do not set any property that has already been set by an initializer

            if ($Initializer.Contains('Operation')) {
                Try { 
                    Write-Verbose "Add initializer- operation correlation" 
                    $OpInit = [Microsoft.ApplicationInsights.Extensibility.OperationCorrelationTelemetryInitializer]::new()
                    $Global:AISingleton.Configuration.TelemetryInitializers.Add($OpInit)
                } catch { 
                    #Warn but do not abort
                    Write-Warning "Could not add the Operation initialiser"
                }
            }


            #Add dependency collector to (automatically ?) measure dependencies 
            if ($Initializer.Contains('Dependency')) {
                Try { 
                    Write-Verbose "Add initializer- dependency collector"
                    $Dependency = [Microsoft.ApplicationInsights.DependencyCollector.DependencyTrackingTelemetryModule]::new();
                    $TelemetryModules = [Microsoft.ApplicationInsights.Extensibility.Implementation.TelemetryModules]::Instance;
                    $TelemetryModules.Modules.Add($Dependency);
                } catch { 
                    #Warn but do not abort
                    Write-Warning "Could not add the Dependency initialiser"
                }

            }

            # Send any unhandled exceptions
            # The module subscribed to AppDomain.CurrentDomain.UnhandledException to send exceptions to ApplicationInsights.

<#            
            $Unhandled =  [Microsoft.ApplicationInsights.WindowsServer.UnhandledExceptionTelemetryModule]::New()
                $TelemetryModules = [Microsoft.ApplicationInsights.Extensibility.Implementation.TelemetryModules]::Instance;
                $TelemetryModules.Modules.Add($Unhandled);
#>
            #Now that they are added, they still need to be initialised
            # Telemetry modules first
            if ($Global:AISingleton.Configuration.TelemetryInitializers) {
                Write-Verbose "Initialize- Telemetry modules"
                $Global:AISingleton.Configuration.TelemetryInitializers | 
                    Where-Object {$_ -is 'Microsoft.ApplicationInsights.Extensibility.ITelemetryModule'} |
                    ForEach-Object { 
                        Try { 
                            $_.Initialize($Global:AISingleton.Configuration); 
                            Write-Verbose ".."
                        } catch { 
                            Write-Warning 'Error during initialisation  of Telemetry Module'
                        }
                    }
            }
            #Then the telemetry processors 
            if ($Global:AISingleton.Configuration.TelemetryProcessorChain.TelemetryProcessors ) { 
                Write-Verbose "Initialize- Telemetry Processors"
		        $Global:AISingleton.Configuration.TelemetryProcessorChain.TelemetryProcessors |
                    Where-Object {$_ -is 'Microsoft.ApplicationInsights.Extensibility.ITelemetryModule'} |
                    ForEach-Object { 
                        Try { 
                            $_.Initialize($Global:AISingleton.Configuration); 
                            Write-Verbose ".."
                        } catch { 
                            Write-Warning 'Error during initialisation  of Telemetry Module'
                        } 
                    }
            } 
            #Now get the initialised modules 
            $TelemetryModules = [Microsoft.ApplicationInsights.Extensibility.Implementation.TelemetryModules]::Instance;
            
            # todo: check if the 2nd initialisation is really needed 
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
                
                if($PSPrivateMetadata.JobId) {
                    # in Azure Automation
                    Write-Verbose "Add Azure Automation and JobID"
                    $client.Context.Cloud.RoleName = 'Azure Automation'
                    $client.Context.Cloud.RoleInstance = $PSPrivateMetadata.JobId

                    $client.Context.Device.OperatingSystem = 'Azure Automation'
                }
                else {
                   # not in Azure Automation
                    Write-Verbose "Add device.OS and User Agent"
                    #OS cannot be read in Azure automation, handle gracefully

                    $OS = Get-CimInstance -ClassName 'Win32_OperatingSystem' -ErrorAction SilentlyContinue
                    if ($OS) {
                        $client.Context.Device.OperatingSystem = $OS.version
                    }
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
                    Write-Verbose "Replacing current active telemetry client, with the new Telemetry client"
                    Flush-AIClient -Client $Global:AISingleton.Client
                    $Global:AISingleton.Client = $null
                } 
                #Save client in Global for re-use when not specified 
                $Global:AISingleton.Client = $client

                if ([string]::IsNullOrEmpty($Version) ) {
                    write-verbose "retrieve version of calling script or module."
                    $Version = getCallerVersion 
                } 
                write-verbose "use version $([string]$version)"
                $client.Context.Component.Version = [string]($version)
                

                #Indicate actual / Synthethic events
                $Global:AISingleton.Client.Context.Operation.SyntheticSource = $Synthetic

                return $client 
            } else { 
                Throw "Could not create ApplicationInsights Client.."
            }
        } catch {
            Throw "Could not create ApplicationInsights Client."
        }
    }
}


<#
.Synopsis
    Flush the Application Insights Queue to the AI Service
    Forces the sending of any remaining messages in the send queue
#>
function Push-AIClient
{
    [CmdletBinding()]
    [Alias("Flush-AIClient")]
    [Alias("Flush-AISession")]  # Depricated 

    Param
    (
        #The AppInsights Telemetry client object to use (Default from singleton).
        [Parameter(Mandatory=$false)]
        [Microsoft.ApplicationInsights.TelemetryClient] $Client 
    )
    #Check for a specified AI client
    if ($Client -eq $null) {
        If ( ($Global:AISingleton ) -AND ( $Global:AISingleton.Client ) ) {
            #Use Current Client
            $Client = $Global:AISingleton.Client
        }
    }
    if ($Client) { 
        $client.Flush()
    } else {
        Write-Verbose 'No Client initialised'
    }
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