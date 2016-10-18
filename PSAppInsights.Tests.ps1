$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

#Module 
$sut = $sut.Replace('.ps1', '.psd1') 
Write-Verbose "$here\$sut" 
import-module "$here\$sut" -force -Verbose

Describe "PSAppInsights" {
    It "loads the AI Dll" {
        New-Object Microsoft.ApplicationInsights.TelemetryClient  -ErrorAction SilentlyContinue | Should not be $null

    }

    Context 'New Session' {
        
        $key = "c90dd0dd-3bee-4525-a172-ddb55873d30a"
        $client = New-AISession -Key $key

        It 'can Init a new log session' {


        
            $client | Should not be $null
            $client.InstrumentationKey -ieq $key | Should be $true
        
            $client.Context.User.UserAgent | Should be $Host.Name
        }
        It 'can Init the log with user information'  {
            $client.Context.User.UserAgent | Should be $Host.Name
            $client.Context.User.Id        | Should be $env:USERNAME
        }

        It 'can Init the log with Computer information' {
            $client.Context.Device.Id              | Should be $env:COMPUTERNAME #Should not be $null
            $client.Context.Device.OperatingSystem | Should not be $null

        }

        #-----------------------------------------

        It 'can log a trace ' {
            {Send-AITrace -Client $client -Message "Test Trace Message" } | Should not throw 
        
            #input validation 
            {Send-AITrace -Client $client -Message $null  } | Should throw 
            {Send-AITrace -Client $null -message "Nope"} | Should throw 

        }

        It 'can log a trace - Complex' -Pending {

        }

        #-----------------------------------------

        It 'can log an event - Simple' {
            {Send-AIEvent -Client $client -Event "Test event - Simple" } | Should not throw 
        
        }

        It 'can log an event - Extended' -Pending {
            #{Send-AIEvent -Client $client -Message "Test Event - Complex" } | Should not throw 
        
        }

        #-----------------------------------------

        It 'can log a Metric' {
            {Send-AIMetric -Client $client -Metric "testMetric" -Value 1} | Should not throw 
       
        }

        It 'can log a Metric - Complex' -Pending {
      
        }

        #-----------------------------------------

        It 'can log an Exception - Simple' {
            {Send-AIException -Client $client -Exception $Error[0].Exception } | Should not throw 

        }

        It 'can log an Exception - Complex' -Pending {

            {Send-AIException -Client $client -Severity 4 -Exception ($Error[0].Exception)  } | Should not throw 
      
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

        It 'can Flush the log session' {
            {Flush-AITrace -Client $client }| Should not throw

        }

        It 'can Flush the log session - Async '  -Skip  {
            {Flush-AITrace -Client $client -NoWait }| Should not throw

        }


    }
}

