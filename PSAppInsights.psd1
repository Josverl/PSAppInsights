#
# Module manifest for module 'PSInsights'
# Generated by: Jos Verlinde
# Generated on: 17-10-2016
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'PSAppInsights'

# Version number of this module.
ModuleVersion = '0.7.2'

# Supported PSEditions
# CompatiblePSEditions = @()

# ID used to uniquely identify this module
GUID = '1706beeb-bb2f-4a51-b1fd-f972e62f4d2d'

# Author of this module
Author = 'Jos Verlinde [MSFT]'

# Company or vendor of this module
CompanyName = 'Microsoft'

# Copyright statement for this module
Copyright = '(c) 2016 josverl. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Use basic and advanced tracing to gain insight to how your scripts are actually working, including errors and functional usage'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '4.0'

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
NestedModules = @(  
    '.\Microsoft.ApplicationInsights.2.1.0\lib\net45\Microsoft.ApplicationInsights.dll',
    '.\Microsoft.ApplicationInsights.WindowsServer.2.1.0\lib\net45\Microsoft.AI.WindowsServer.dll',
    '.\Microsoft.ApplicationInsights.PerfCounterCollector.2.1.0\lib\net45\Microsoft.AI.PerfCounterCollector.dll'
)


# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = '*'

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = '*'

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('Tracing','ApplicationInsights')

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/Josverl/Connect-O365/raw/master/License'

        # A URL to the main website for this project.
        # ProjectUri = ''
        # A URL to an icon representing this module.
        IconUri = 'https://raw.githubusercontent.com/Josverl/Connect-O365/master/Connect-O365'

        # ReleaseNotes of this module
        ReleaseNotes = @"
V0.7     Add Collection of Performance Counters, Update to PSGallery
V0.6.2   Add caller's script or module version information to start-AISession
V0.6.1   Automatically add caller information on new Session (Script,  Line Number )
V0.6.0.2 Resolve naming collision for get-hash 
V0.5     initial publication 
"@                         

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

