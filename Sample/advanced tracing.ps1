<#
 # Sample of helper functions and extended tracing
#>

# The ConvertTo-Hashtable cmdlet converts an object's properties to a hashtable 
# the contents of such a hashtable can be attached to an event or trace using -properties $hashtable 
# in order to log that information to AppInsights 

#send information for all processes, one event per process, with all attributes of the process.
Get-Process | %{ Send-AIEvent "Win32 Process" -Properties ($_ | ConvertTo-Hashtable) }
