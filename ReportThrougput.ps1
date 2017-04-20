<#
.Synopsis
    Log some metrics to AI to capture thoughput 
.DESCRIPTION
    
#>

#Requires -Module PSAppInsights

#Instrumentation key 
$key = "b437832d-a6b3-4bb4-b237-51308509747d"

#start logging metrics for this powershell process 
New-AIClient -Key $key -SendingInterval 2

$SW = New-Stopwatch
 
 1 .. 50| %{

    $SW.Restart()

    #do stuff
    Sleep -Milliseconds (Get-Random -Maximum 2000 -Minimum 100) 
    
    $USERCOUNT = 200 
        
    Send-AIMetric -Metric "User/s" -Value ( $uSERcOUNT / ($SW.Elapsed).TotalSeconds) -Verbose

 }

 $sw.Stop() 
 REMOVE-VARIABLE sw
 Stop-AIClient | Out-Null



