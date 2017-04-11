<#
.Synopsis
    Starts logging a live metrics stream to App Insights
.DESCRIPTION
    The logging stream sends a standard set of perfcounters every second, which allows you to monitor essential counters directly in AppInsights.
    
    Please note that this will incur a continous stream of performance and statictics to the azure AppInsights portal,
    this is in the format of a HTTPS traffic stream which will send about 5 to 6 MBytes per hour to https://rt.services.visualstudio.com

    This information is sent asynchronously from the powershell script or module and requires no interaction other that starting or stopping.
    Please note that there is only a single LiveMetrics view for each Instrumentation key.
    > If multiple instances of the same script log to the same Key the counters will be combined
    > if you need to view seperate LiveMetrics, you need to instrument your scripts with different keys.
#>

#Instrumentation key 
$key = "b437832d-a6b3-4bb4-b237-51308509747d"

#start logging metrics for this powershell process 
Start-AILiveMetrics -Key $key 

1..10 | % {
    $mem_stress = @()
    1..6 | %{
        Write-Host "Eat..." -NoNewline
        #Eat some memory
        for ($i = 0; $i -lt 5000; $i++) { $mem_stress += ("a" * 200MB) }
        Write-Host "Sleep..." -NoNewline
        Start-Sleep -Seconds 2
    }
    Remove-Variable mem_stress
    Write-Host "Rave, Repeat." 
}        

Stop-AILiveMetrics
Write-Host "Done."