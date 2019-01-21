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

    The AI default set of perfcounters is : 

    "\.NET CLR Exceptions(??APP_CLR_PROC??)\# of Exceps Thrown / sec"
    "\Memory\Available Bytes"
    "\Process(??APP_WIN32_PROC??)\% Processor Time Normalized"
    "\Process(??APP_WIN32_PROC??)\% Processor Time"
    "\Process(??APP_WIN32_PROC??)\IO Data Bytes/sec"
    "\Process(??APP_WIN32_PROC??)\Private Bytes"
    "\Processor(_Total)\% Processor Time"

    "\ASP.NET Applications(??APP_W3SVC_PROC??)\Request Execution Time"
    "\ASP.NET Applications(??APP_W3SVC_PROC??)\Requests In Application Queue"
    "\ASP.NET Applications(??APP_W3SVC_PROC??)\Requests/Sec"

    If you do not have IIS running, AI will report that it cannot collect the three W3SVC counters as part of the telemetry it sends.
    after that is will stop trying to collect these counters, so you can safgly ignore that.

#> 

#Instrumentation key 
$key = "b437832d-a6b3-4bb4-b237-51308509747d"

#Start logging the default set of perf counters 
Start-AIPerformanceCollector -Key $key -Fiddler -SendingInterval 5 -DeveloperMode

Write-Host 'let the counters run for 2 minutes'
Start-Sleep -Seconds (2*60)

#Stop sending the counters
Stop-AIPerformanceCollector



#get list of all process counters  
$ProcessCounters = (Get-Counter -ListSet "Process").paths | ForEach-Object{ $_.Split('\')[2]}

#Start logging
Start-AIPerformanceCollector -Key $key -ProcessCounters $ProcessCounters -SendingInterval 5 -DeveloperMode
Write-Host 'let the counters run for 2 minutes'
Start-Sleep -Seconds (2*60)

#Stop sending the counters
Stop-AIPerformanceCollector
Write-Host 'done'
