<#
.Synopsis
    Start collection perfromance counters and send them to App Insights

    The collection includes perf counters of the powershell process tha runs the script.
   
    By default the following perf counters are collected : 
    - Handle Count 
    - Working Set 

    If other process counters are to be collected these can be specified using -ProcessCounters
    (currently only process counters are supported)

    The perfmon collector is mantained per (powershell) process, and a reference to the collectore is stored in a global variable.
    $Global:AISingleton.PerformanceCollector

    By default the counters are collected and sent every 30 seconds
#> 

#Instrumentation key 
$key = "c90dd0dd-3bee-4525-a172-ddb55873d30a"

#Start logging the default set of perf counters 
Start-AIPerformanceCollector -Key $key

#get list of all process counters  
$ProcessCounters = (Get-Counter -ListSet "Process").paths | %{ $_.Split('\')[2]}

#Start logging
Start-AIPerformanceCollector -Key $key -ProcessCounters $ProcessCounters

#let the counters run for 10 minutes 
Start-Sleep -Seconds 10*60

#Stop sending the counters
Stop-AIPerformanceCollector