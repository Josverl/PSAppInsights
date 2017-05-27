<#PSScriptInfo
.DESCRIPTION 
    Pester tests for PowerShell App Insights Module
    The script .Version 1.2.3 is used in test, 
    do not modify withouth changing the test can detect the calling script version' 
.VERSION 1.2.3
.AUTHOR Jos Verlinde
.GUID bcff6b0e-509e-4c9d-af31-dccc41e148d0
#>
#Suppress wanrings about variables not being used for this file 
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]

Param ( 
    #switch to test the installed module after initial test deployment  
    [switch]$TestInstalledModule
)

#Load Fiddler Module to see what is sent across the wire 
Import-Module .\Tests\FiddlerTests.psm1 -Force -DisableNameChecking

#Make sure A fresh fiddler is started 
#Stop-Fiddler 
Ensure-Fiddler
Write-Verbose 'Wait for fiddler' -Verbose
Start-Sleep 4 
Stop-FiddlerCapture

Get-Module -Name 'PSAppInsights' -All | Remove-Module -Force -ErrorAction SilentlyContinue
if ($TestInstalledModule) { 
    Write-Verbose 'Load locally installed module' -Verbose
    $M = Import-Module -Name PSAppInsights -PassThru
    $m | Format-Table Name,version, Path

} else { 
    Write-Verbose '--------- Load Module under development ------------' -Verbose 
    Import-Module ".\PSAppInsights.psd1" -Force 

}

#Common test function 
Function FilterCapture {
Param (
    $Capture,
    [string]$Type = 'Event')
    $Type = $Type.Trim()
    $MyTelemetry = @( $Capture.AllTelemetry | Where-Object name -like "Microsoft.ApplicationInsights.*.$Type" ) 
    if ($MyTelemetry.Count -lt $Capture.AllTelemetry.Count ) {
        Write-warning ('{0} Additional telemetry records were captured' -f ($MyTelemetry.Count - $Capture.AllTelemetry.Count) )
    }
    Write-Output $MyTelemetry
}


Describe 'should fail silently if no client is started' {
    BeforeAll {
        Stop-AIClient -WarningAction SilentlyContinue
        
        $ST = New-Stopwatch
        $ST.Start
        #For Exception and error handling
        $ex = new-object System.Management.Automation.ApplicationFailedException
        try  
        {  
            $fileContent = Get-Content -Path "C:\Does.not.exists.txt" -ErrorAction Stop  
        }  
        catch  
        {  
            $ex = $_.Exception
            $er = $_ 
        }
    }
    AfterAll {
        $ST.Stop()
        Stop-FiddlerCapture 
    }
    It 'Should not throw errors using the default client' { 
       {Send-AIEvent -Event 'Test'  } | Should not throw 
       {Send-AITrace -Message 'Test Trace'  } | Should not throw 
       {Send-AIMetric -Metric 'Test' -Value 42 } | Should not throw 
       {Send-AIDependency -StopWatch $ST -Name 'Test'  } | Should not throw 
       {Send-AIException -Exception  $ex } | Should not throw 
    }
    It 'Should not throw errors flushing the default client'  { 
        {Flush-AIClient } | Should not throw 
        {Stop-AIClient } | Should not throw 
    }

    It 'Should not throw errors using a Specified client' { 
       {Send-AIEvent -Client $null -Event 'Test'  } | Should not throw 
       {Send-AITrace -Client $null  -Message 'Test Trace'  } | Should not throw 
       {Send-AIMetric -Client $null  -Metric 'Test' -Value 42 } | Should not throw 
       {Send-AIDependency -Client $null -StopWatch $ST -Name 'Test'  } | Should not throw 
       {Send-AIException -Client $null -Exception  $ex } | Should not throw 
    }
    It 'Should not throw errors flushing  a Specified client' { 
        {Flush-AIClient -Client $null } | Should not throw 
        {Stop-AIClient -Client $null } | Should not throw 
    }

}

Describe "PSAppInsights Module" {
    It "loads the AI Dll"  -Pending {
        New-Object Microsoft.ApplicationInsights.TelemetryClient  -ErrorAction SilentlyContinue -Verbose| Should not be $null
        #Use Get-modules  to list all loaded DLLs and check for the expected ones 
    }




    BeforeAll { 
       
        $key = "b437832d-a6b3-4bb4-b237-51308509747d" #AI Powershell-test 

        $PropHash = @{ "Pester" = "Great";"Testrun" = "True" ;"PowerShell" = $Host.Version.ToString() } 
        $MetricHash = @{ "Powershell" = 5;"year" = 2016 } 

        #For Exception and error handling
        $ex = new-object System.Management.Automation.ApplicationFailedException
        try  
        {  
            $fileContent = Get-Content -Path "C:\Does.not.exists.txt" -ErrorAction Stop  
        }  
        catch  
        {  
            $ex = $_.Exception
            $er = $_ 
        }

    }
    
    Context 'New Session' {
        BeforeEach {
            Start-FiddlerCapture 
        }
        AfterEach {
            Stop-FiddlerCapture
        }


        it 'detects an invalid iKey' -Pending { 
            # Start 
            # send 
            # Stop 

            #Check using fiddler 
            #{"itemsReceived":1,"itemsAccepted":0,"errors":[{"index":0,"statusCode":400,"message":"Invalid instrumentation key"}]}
        }



        It 'can Init a new log AllowPII session' {
            $Version = "2.3.4"
            $client = New-AIClient -Key $key -AllowPII -Version $Version
            
            $Global:AISingleton.Client | Should not be $null

            $client | Should not be $null
            $client.InstrumentationKey -ieq $key | Should be $true
        
            $client.Context.User.UserAgent | Should be $Host.Name

            #Check PII 
            $client.Context.Device.Id      | Should be $env:COMPUTERNAME 
            $client.Context.User.Id        | Should be $env:USERNAME

            #Check Version number detection
            $Client.Context.Component.Version | should be $Version
            Send-AIEvent 'Ping'
            Flush-AIClient
            #Now check what has been transmitted 
            $Capture = Get-FiddlerCapture  
            $Capture.ErrorCount | Should be 0
            #Filter
            [array]$MyTelemetry = FilterCapture $Capture -Type 'Event'
            $MyTelemetry.Count | Should be 1
            if ($MyTelemetry.Count -eq 1) { 
                $MyTelemetry[0].tags.'ai.application.ver' | Should be $Version
                $MyTelemetry[0].tags.'ai.user.id' | Should be $env:USERNAME
                $MyTelemetry[0].tags.'ai.device.id' | Should be $env:COMPUTERNAME 

                $MyTelemetry[0].tags.'ai.user.userAgent' | Should be  $Host.Name

                $MyTelemetry[0].tags.'ai.operation.id' -in '<No file>','PSAppInsights.Tests.ps1','Pester.psm1'  | Should be $true
            }
        }


        It 'can Init Device properties' {

            { $TmtClient = New-AIClient -Key $key  -Init Device } | Should not Throw 
            
            Send-AIEvent 'Ping'
            Flush-AIClient
            #Now check what has been transmitted 
            $Capture = Get-FiddlerCapture  
            $Capture.ErrorCount | Should be 0
            #Filter
            [array]$MyTelemetry = FilterCapture $Capture -Type 'Event'
            $MyTelemetry.Count | Should be 1
            if ( $MyTelemetry.Count -eq 1) { 
                $MyTelemetry[0].tags.'ai.device.osVersion'     | Should not be "" #  10.0.14393
                $MyTelemetry[0].tags.'ai.device.oemName'       | Should not be "" #  LENOVO
                $MyTelemetry[0].tags.'ai.device.model'         | Should not be "" #  20FRS02N12
                $MyTelemetry[0].tags.'ai.device.type'          | Should not be "" #  PC
            }            
        }
        it 'can Init  Domain properties' {    

            { $TmtClient = New-AIClient -Key $key -Init Domain } | Should not Throw 

            Send-AIEvent 'Ping'
            Flush-AIClient
            #Now check what has been transmitted 
            $Capture = Get-FiddlerCapture  
            $Capture.ErrorCount | Should be 0
            #Filter
            [array]$MyTelemetry = FilterCapture $Capture -Type 'Event'            
            $Mytelemetry.Count | Should be 1

            if ($Mytelemetry.Count -eq 1) { 

                #TODO Add tests
            }                            
        }
        it 'can Init Operation Correlation' {    

            {  $TmtClient = New-AIClient -Key $key -Init Operation  } | Should not Throw 
        }
        it 'can Init Device & Domain & Operation' {    

            { $TmtClient = New-AIClient -Key $key -Init @('Device', 'Domain', 'operation' ) } | Should not Throw 
        }


        it 'can detect the calling script version' {
            $client = New-AIClient -Key $key -AllowPII -Init Device, Domain, Operation
           
            #Check Version number  (match this script's version ) 
            $ScriptVersion = "1.2.3" 
            $Client.Context.Component.Version | should be  $ScriptVersion

            Send-AIEvent 'Ping'
            Flush-AIClient
            #Now check what has been transmitted 
            $Capture = Get-FiddlerCapture  
            #Filter
            [array]$MyTelemetry = FilterCapture $Capture -Type 'Event'

            $MyTelemetry.Count | Should be 1
            if ($MyTelemetry.Count -eq 1) { 
                $MyTelemetry[0].tags.'ai.application.ver' | Should be $ScriptVersion               
            }
        }

        it 'can log permon counters in developer mode' {
            $Global:AISingleton.PerformanceCollector = $null
            { start-AIPerformanceCollector -key $key -DeveloperMode }| Should not throw
            $Global:AISingleton.PerformanceCollector | Should not be $null
        }

        it 'can log permon counters in with a specified interval' {
            $Global:AISingleton.PerformanceCollector = $null

            { start-AIPerformanceCollector -key $key -SendingInterval 360 }| Should not throw
            $Global:AISingleton.PerformanceCollector | Should not be $null
            $TimeSpan = [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.TelemetryChannel.SendingInterval
            $TimeSpan.TotalSeconds | Should be 360
        }


        it 'can log permon counters' {
            $Global:AISingleton.PerformanceCollector = $null
            { start-AIPerformanceCollector -key $key }| Should not throw
            $Global:AISingleton.PerformanceCollector | Should not be $null

            #And a 2nd time 
            { start-AIPerformanceCollector -key $key }| Should not throw
            $Global:AISingleton.PerformanceCollector | Should not be $null

        }

        It 'can run in developer mode ' {
            #Mark Pester traffic As Synthethic traffic (Keep on ) 
            $Client = $Null
            { $client = New-AIClient -Key $key -DeveloperMode} | Should not Throw
            $client = New-AIClient -Key $key -DeveloperMode
            $Client | Should not be $Null
        }



        It 'Can set the SendingInterval' {
            #Mark Pester traffic As Synthethic traffic (Keep on ) 
            $Client = $Null
            #Check out of bound parameters 
            { $client = New-AIClient -Key $key -SendingInterval 0} | Should Throw
            { $client = New-AIClient -Key $key -SendingInterval -1} | Should Throw
            { $client = New-AIClient -Key $key -SendingInterval 1441} | Should Throw
            
            #Check some valid ranges 
            
            ( 1440, 10 , 360 , 60 ) | ForEach-Object {  
                $Seconds = $_
                { $client = New-AIClient -Key $key -SendingInterval $Seconds} | Should not Throw
                $Client = $Null
                $client = New-AIClient -Key $key -SendingInterval $Seconds
                $Client | Should not be $Null
                $TimeSpan = [Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration]::Active.TelemetryChannel.SendingInterval
                $TimeSpan.TotalSeconds | Should be $Seconds
            } 

        }




        It 'Mark Pester traffic As Synthethic traffic (Keep on ) ' {
            #Mark Pester traffic As Synthethic traffic (Keep on ) 
            $SynthMarker= "Pester run $((get-date).ToString('g'))"
            $client = New-AIClient -Key $key -Synthetic $SynthMarker
        }

        #TestHack to avoid loosing the vlau of client due to scope 
        #Todo: improve logic
        $SynthMarker= "Pester run $((get-date).ToString('g'))"
        $client = New-AIClient -Key $key -Synthetic $SynthMarker

        It 'can Init a new log session' {

            $client | Should not be $null
            $client.InstrumentationKey -ieq $key | Should be $true
        
            $client.Context.User.UserAgent | Should be $Host.Name
        }
        it 'can mark synthetic traffic' {
            $AISingleton.Client.Context.Operation.SyntheticSource | Should be $SynthMarker
        }

        It 'can Init the log with user information'  {
            $client.Context.User.UserAgent | Should  be $Host.Name
            $client.Context.User.Id        | Should not be $env:USERNAME
            $client.Context.User.Id        | Should not be $null

        }

        It 'can Init the log with Computer information' {
            $client.Context.Device.Id              | Should not be $env:COMPUTERNAME #Should not be $null
            $client.Context.Device.Id              | Should not be $null
            $client.Context.Device.OperatingSystem | Should not be $null

        }

        It 'can log live metrics'  {
            { Start-AILiveMetrics -Key $key } | Should not Throw
            $Global:AISingleton.QuickPulse | Should not be $null
        }

        #-----------------------------------------

        It 'can log a trace .1' {
            Send-AITrace -Message "Test Trace Message" 
            
            {Send-AITrace -Message "Test Trace Message" } | Should not throw 

            {Send-AITrace -Client $client -Message "Test Trace Message" } | Should not throw 
        }            
        It 'can log a trace .3' {
            #using Global 
            {Send-AITrace -Message "Test Trace Message" } | Should not throw 
        }            
        It 'can log a trace .3' {
            {Send-AITrace -Message "Test Trace Message" -SeverityLevel 0 } | Should not throw 

        }

        It 'can log a trace - Complex' {

            #using Global 
            {Send-AITrace -Message "Test Trace Message" -Properties $PropHash} | Should not throw 
        }
        It 'can log a trace - Complex + Levels' {

            {Send-AITrace -Message "Test Trace Message" -Properties $PropHash -SeverityLevel "Verbose" } | Should not throw 
            {Send-AITrace -Message "Test Trace Message" -Properties $PropHash -SeverityLevel "Information" } | Should not throw 
            {Send-AITrace -Message "Test Trace Message" -Properties $PropHash -SeverityLevel "Error" } | Should not throw 
            {Send-AITrace -Message "Test Trace Message" -Properties $PropHash -SeverityLevel "Warning" } | Should not throw 
            {Send-AITrace -Message "Test Trace Message" -Properties $PropHash -SeverityLevel "Critical" } | Should not throw 

            {Send-AITrace -Message "Test Trace Message" -Properties $PropHash -SeverityLevel 0 } | Should not throw 
            {Send-AITrace -Message "Test Trace Message" -Properties $PropHash -SeverityLevel 1 } | Should not throw 
            {Send-AITrace -Message "Test Trace Message" -Properties $PropHash -SeverityLevel 2 } | Should not throw 
            {Send-AITrace -Message "Test Trace Message" -Properties $PropHash -SeverityLevel 3 } | Should not throw 
            {Send-AITrace -Message "Test Trace Message" -Properties $PropHash -SeverityLevel 4 } | Should not throw 

        }

        #-----------------------------------------
        
        It 'can log an event - Simple , implicit' {
            #Using Global
            {Send-AIEvent -Event "Test event - Simple Implicit" } | Should not throw 
        }

        It 'can log an event - Simple , explicit' {
            {Send-AIEvent -Client $client -Event "Test event - Simple Explicit" } | Should not throw 
        }


        It 'can log an event - NoStack' {
            {Send-AIEvent -Client $client -Event "Test event - Simple, no stack" -NoStack } | Should not throw 
        
        }

        It 'can log an event - Stackwalk ' {
            {Send-AIEvent -Client $client -Event "Test event - Simple, no stack" -StackWalk 1 } | Should not throw 
        }

        It 'can log an event - Negative Stackwalk' -Skip {
                {Send-AIEvent -Client $client -Event "Test event - Simple, no stack" -StackWalk -1 } | Should  throw 
        }

        It 'can log an event - with metrics'  {
            # BUGBUG on the sending end 
            # {"name":"Microsoft.ApplicationInsights.c90dd0dd3bee4525a172ddb55873d30a.Event","time":"2016-10-27T20:10:24.5050618Z","iKey":"b437832d-a6b3-4bb4-b237-51308509747d","tags":{"ai.internal.sdkVersion":"dotnet: 2.1.0.26048","ai.device.osVersion":"10.0.14393","ai.operation.id":"db0c5074-8350-45b9-9c13-754fc8388ead","ai.session.id":"a9f87484-02b3-470d-a1b7-99189af7c34e","ai.user.userAgent":"Windows PowerShell ISE Host","ai.user.id":"ba3734482aa24856f1d253a5bae74e06","ai.device.id":"518aeec5d382166090a20484145b67f9"},"data":{"baseType":"EventData","baseData":{"ver":2,"name":"name is a required field for Microsoft.ApplicationInsights.DataContracts.EventTelemetry","properties":{"ScriptName":"<No file>","Command":"<ScriptBlock>","FunctionName":"<ScriptBlock>","ScriptLineNumber":"1"}}}}
            {Send-AIEvent -Client $client -Event "Test Event - Complex" -Metrics $MetricHash} | Should not throw 
        }

        It 'can log an event - with Properties'  {
            $hash = @{ "Pester" = "Great";"Testrun" = "True"  } 
            {Send-AIEvent -Client $client -Event "Test Event - Complex" -Properties $PropHash} | Should not throw 
        }

        It 'can log an event - with metrics' {
            $hash = @{ "Pester" = "Great";"Testrun" = "True"  } 
            {Send-AIEvent -Client $client -Event "Test Event - Complex" -Metrics $MetricHash -Properties $PropHash} | Should not throw 
        }

        #-----------------------------------------

        It 'can log a Metric' {
            {Send-AIMetric -Client $client -Metric "testMetric" -Value 1} | Should not throw 
            #Using Global
            {Send-AIMetric -Metric "testMetric" -Value 1} | Should not throw 
       
        }

        It 'can log a Metric - Complex' {
            #Using Global
            {Send-AIMetric -Metric "testMetric" -Value 1 -Properties $PropHash } | Should not throw 
      
        }

        #-----------------------------------------
        $ex = new-object System.Management.Automation.ApplicationFailedException
        try  
        {  
            $fileContent = Get-Content -Path "C:\Does.not.exists.txt" -ErrorAction Stop  
        }  
        catch  
        {  
            $ex = $_.Exception
            $er = $_ 
        }


        It 'can log an Exception - Simple' {

            {Send-AIException -Client $client -Exception  $ex } | Should not throw 
            #Using Global
            {Send-AIException -Exception  $ex } | Should not throw 

        }
        It 'can log an Exception Via an Error object ' {
            {Send-AIException -Severity 4 -Error $Er  } | Should not throw 
      
        }

        It 'can log an Exception - Complex' {
            {Send-AIException -Client $client -Severity 4 -Exception $ex -Properties $PropHash  } | Should not throw 
            {Send-AIException -Client $client -Severity 4 -Exception $ex -Metrics $MetricHash   } | Should not throw 
            {Send-AIException -Client $client -Severity 4 -Exception $ex -Metrics $MetricHash -Properties $PropHash  } | Should not throw 
      
        }
        It 'can log a NULL Exception' -Pending {

            {Send-AIException -Client $client -Exception  $NULL} | Should not throw 
            #Using Global
            {Send-AIException -Exception  $NULL } | Should not throw 

        }
        #-----------------------------------------

        It 'can log a Page view ' -Skip {
       
        }

        #-----------------------------------------


        It 'can log server request - One Off ' -Skip {
        
        }

        It 'can Start a Server Request' -Skip {
        
        }

        It 'can Finalize a Server Request' -Skip {
        
        }

        #-----------------------------------------



        It 'can Push/Flush the log session' {
            {Flush-AIClient -Client $client }| Should not throw
            {Push-AIClient -Client $client }| Should not throw

        }

        It 'can close the log session' {
            {Stop-AIClient -Client $client }| Should not throw
        }


        it 'can stop logging permon counters' {
            { stop-AIPerformanceCollector }| Should not throw
            $Global:AISingleton.PerformanceCollector | Should be $null
        }

        It 'can stop loggin log live metrics' {
            { Stop-AILiveMetrics } | Should not Throw
            $Global:AISingleton.QuickPulse | Should be $null
        }


    }
}


Describe 'AI Dependency Nested Module' {

    BeforeAll {

        #AI Powershell-test 

        $key = "b437832d-a6b3-4bb4-b237-51308509747d"
        $Watch1 = new-Stopwatch
    }
    
#    AfterAll {
#        Remove-Module -Name AIDependency -Force -ErrorAction SilentlyContinue
#    }

    It 'can start a AI Client with dependency tracking' {
        $client = New-AIClient -Key $key -Initializer Dependency

        {$c2 = New-AIClient -Key $key -Initializer Dependency} | Should not Throw
        $client | Should not be $null
    }

    It 'can start a Stopwatch' {
        $Watch1 | should not be $null
        $Watch1.GetType()  | should be 'System.Diagnostics.Stopwatch'
    }
    It 'Depedency can use a stopwatch' {
        $Watch1.Stop()
        { Send-AIDependency -StopWatch $Watch1 -Name "TEST Dept." } | Should not Throw
    } 
    
    It 'Dependency can use a Duration - 1' {
         $TS = Measure-Command { Start-Sleep (Get-Random 1 ) }
        { Send-AIDependency -TimeSpan $TS -Name "TEST Dept." } | Should not Throw
    }
    It 'Dependency can use a Duration from the pipeline - 2'  {

        {  Measure-Command { Start-Sleep (Get-Random 1 ) } | Send-AIDependency -Name "TEST Dept." } | Should not Throw
    
    }
    $TS = Measure-Command { Start-Sleep (Get-Random 1 ) }
    It 'Dependency can Send Failure'  {
        {   
            Send-AIDependency -Name "TEST Dept." -TimeSpan $TS -Success $false # not in 2.3.0 -ResultCode 500 

        
         } | Should not Throw
    }

    It 'Dependency can be set to SQL'  {
        {   
            Send-AIDependency -Name "TEST SQL." -TimeSpan $TS -Success $True -DependencyKind SQL -CommandName "DROP *"
        
         } | Should not Throw
    }

    It 'Dependency can be set to HTTP'  {
        {   
            Send-AIDependency -Name "TEST HTTP" -TimeSpan $TS -Success $True -DependencyKind HTTP -CommandName "http://powershellgallery.com"
        
         } | Should not Throw
    }

    It 'can do a few measurements' { 

        "bing.com", "google.com" | ForEach-Object{ 
            $url = $_
            $Timespan = Measure-Command {
                Invoke-WebRequest $url
            }

            {Send-AIDependency -Name $url -TimeSpan $Timespan -DependencyKind HTTP  } | Should not Throw
        }
    }

}

