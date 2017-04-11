﻿<#
 # Demonstration of the Exeption Logging capabilities of Application Insights 
#>

#Import the module
Import-Module .\PSAppInsights.psd1 -Force 
$key = "b437832d-a6b3-4bb4-b237-51308509747d"


#init a client and send basic non-PII information for correlation
#this includes identifiers hashed(username) and hashed(machine name)  
$Client = New-AIClient -Key $key -Verbose -Fiddler -Initializer Dependency

Send-AIEvent "Basic Hashed non-PII information" -Flush

Throw "Error"