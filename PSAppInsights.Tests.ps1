<#
    Pester tests for PowerShell App Insights Module
    V0.3
#>

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

#Module 
$sut = $sut.Replace('.ps1', '.psd1') 
Write-Verbose "$here\$sut" 
import-module "$here\$sut" -force 

Describe "PSAppInsights Module" {
    It "loads the AI Dll" {
        New-Object Microsoft.ApplicationInsights.TelemetryClient  -ErrorAction SilentlyContinue | Should not be $null
    }

    $key = "c90dd0dd-3bee-4525-a172-ddb55873d30a"

    $PropHash = @{ "Pester" = "Great";"Testrun" = "True" ;"PowerShell" = $Host.Version.ToString() } 
    $MetricHash = @{ "Powershell" = 5;"year" = 2016 } 


    Context 'New Session' {

        It 'can Init a new log AllowPII session' {

            $client = New-AISession -Key $key -AllowPII
        
            $client | Should not be $null
            $client.InstrumentationKey -ieq $key | Should be $true
        
            $client.Context.User.UserAgent | Should be $Host.Name

            #Check PII 
            $client.Context.Device.Id      | Should be $env:COMPUTERNAME 
            $client.Context.User.Id        | Should be $env:USERNAME

        }



        $client = New-AISession -Key $key

        #Mark Pester traffic As Synthethic traffic
        $AIClient.Context.Operation.SyntheticSource = $true

        It 'can Init a new log session' {

            $client | Should not be $null
            $client.InstrumentationKey -ieq $key | Should be $true
        
            $client.Context.User.UserAgent | Should be $Host.Name
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

        #-----------------------------------------

        It 'can log a trace ' {
            {Send-AITrace -Client $client -Message "Test Trace Message" } | Should not throw 
            
            #using Global 
            {Send-AITrace -Message "Test Trace Message" } | Should not throw 

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

        It 'can log an event - Simple' {
            {Send-AIEvent -Client $client -Event "Test event - Simple" } | Should not throw 
            
            #Using Global
            {Send-AIEvent -Event "Test event - Simple" } | Should not throw 
        }

        It 'can log an event - NoStack' {
            {Send-AIEvent -Client $client -Event "Test event - Simple" -Stack:$False -Verbose} | Should not throw 
        
        }


        It 'can log an event - with metrics'  {
            
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
        It 'can log an Exception Via an Error object ' -Pending {
            {Send-AIException -Severity 4 -Error $Er  } | Should not throw 
      
        }

        It 'can log an Exception - Complex' -Pending  {
            {Send-AIException -Client $client -Severity 4 -Exception $ex -Properties $PropHash  } | Should not throw 
            {Send-AIException -Client $client -Severity 4 -Exception $ex -Metrics $MetricHash   } | Should not throw 
            {Send-AIException -Client $client -Severity 4 -Exception $ex -Metrics $MetricHash -Properties $PropHash  } | Should not throw 
      
        }

        #-----------------------------------------

        It 'can log a Page view ' -Skip {
       
        }

        #-----------------------------------------


        It 'can log server request - One Off ' {
        
        }

        It 'can Start a Server Request' {
        
        }

        It 'can Finalize a Server Request' {
        
        }

        #-----------------------------------------


        It 'can log and trace a dependency' {
        
        }

        It 'can Push/Flush the log session' {
            {Push-AISession -Client $client }| Should not throw

        }

        It 'can Push/Flush the log session - Async '  -Skip  {
            {Push-AISession -Client $client -NoWait }| Should not throw

        }

    }
}

<#
TODO Improve Exception test 

#>
