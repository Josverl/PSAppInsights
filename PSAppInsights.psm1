
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
function New-AISession
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(#Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Key = "c90dd0dd-3bee-4525-a172-ddb55873d30a",

        # Set to suppress sending messages in a test environment
        [switch]$Synthetic 
    )

    Process
    {
        $client = New-Object Microsoft.ApplicationInsights.TelemetryClient  
        $client.InstrumentationKey = $Key

        #Id: A generated value that correlates different events, so that you can find "Related items"
        $client.Context.Operation.Id = New-Guid

        #do some standard init on the context 
        $client.Context.Device.OperatingSystem = (Get-CimInstance Win32_OperatingSystem).version
        $client.Context.Device.Id = $env:COMPUTERNAME #Need to hash this

        #$client.Context.Properties.

        $client.Context.User.UserAgent = $Host.Name
        #$client.Context.Session.Id = New-Guid
        $client.TrackTrace("Hello Event" )
        $client.Flush()
        return $client 
    }
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
function Send-AITrace
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Param1,

        # Param2 help description
        [int]
        $Param2
    )

    Begin
    {
    }
    Process
    {
    }
    End
    {
    }
}

