<#
 # Demonstration of the basic capabilities of Application Insights 
#>

#Import the module
Import-Module .\PSAppInsights.psd1 -Force 
$key = "b437832d-a6b3-4bb4-b237-51308509747d"


#init a client and send basic non-PII information for correlation
#this includes identifiers hashed(username) and hashed(machine name)  
$Client = New-AIClient -Key $key -Verbose
Send-AIEvent "Basic Hashed non-PII information"


#init a client and send basic PII information for correlation
#this incudes the username and the machine name
$Client = New-AIClient -Key $key -AllowPII 
Send-AIEvent "Allow PII" -Flush


#Start a client and initialize it with the device context 
#Device details are retrieved from the bios and include vendor and type information, and the machine name 
$Client = New-AIClient -Key $key -Verbose -Init Device 
Send-AIEvent "Device Info" -Flush

#Start a client and initialize it with the AD domain details.
#this includes the full daomain andmachinename if the machineisdomain joined.
$Client = New-AIClient -Key $key -Verbose -Init Domain 
#send an event that will be decorated with the Domain details 
Send-AIEvent "Domain" -Flush

#Start a client and initialize it with both the device, and the AD domain details.
$Client = New-AIClient -Key $key -Verbose -Init @('Device', 'Domain') 
Send-AIEvent "Device & Domain" -Flush

#Stop logging
Stop-AIClient
