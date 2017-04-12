Write-host -ForegroundColor Yellow  'Run the normal build and test suite using the DEV repro'
invoke-psake .\default.ps1

Get-Module psappinsights
Get-InstalledModule psappinsights -AllVersions | FT
