<#
 # test Send Event
#>
param( 
    #AI Instrumentation Key
    [string]$Key,
    [switch]$fiddler = $true
)


function MyFunction 
{
    param (
        [ValidateSet("Low", "Average", "High")]
        [String[]] $Detail
    )

    $Detail.Count

    $detail.Contains("Low")

    $Detail | FT
}


MyFunction -Detail Low, Average 


Import-Module PSAppInsights 
#$key = "c90dd0dd-3bee-4525-a172-ddb55873d30a"
$key = "a7162c29-8478-4bf4-a831-da8819b80496" #ConnectO365
$key = "b437832d-a6b3-4bb4-b237-51308509747d" #PowerShell

#Create default config 
#$AIConfig = [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::CreateDefault()


# Is this a singleton that controls all New AI Client sessions from this moment 
[Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.InstrumentationKey = $key

#optionally add Fiddler for debugging
if ($fiddler) { 
    [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.TelemetryChannel.EndpointAddress = 'http://localhost:8888/v2/track'
}

$AIconfig = [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active
$AIconfig.TelemetryInitializers.Count
$AIconfig.TelemetryInitializers[0].ToString()

$Init = [Microsoft.ApplicationInsights.WindowsServer.DomainNameRoleInstanceTelemetryInitializer]::new()
$AIconfig.TelemetryInitializers.Add($Init)

$Init = [Microsoft.ApplicationInsights.Extensibility.OperationCorrelationTelemetryInitializer]::new()
$AIconfig.TelemetryInitializers.Add($Init)

$DeviceInit = [Microsoft.ApplicationInsights.WindowsServer.DeviceTelemetryInitializer]::new()
$AIconfig.TelemetryInitializers.Add($DeviceInit)

$client = [Microsoft.ApplicationInsights.TelemetryClient]::new($AIconfig)

$client.Context.Operation.Name="Operation 1"
$client.Context.Operation.
#log 
#[Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active
#[Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.TelemetryChannel

#This is OK 
Send-AITrace "Trace" -Flush -Client $client -NoStack

#This fails 
Send-AIEvent "Event" -Flush

#This also fails 
Send-AIEvent "Event" -Flush -NoStack

#
$client.TrackEvent("Event 1") 
$client.TrackEvent("Event 2",$null,$null) 
$client.Flush()




