Write-host -ForegroundColor Yellow  'Run the normal build and test, in finish by publishing to PSGallery'
invoke-psake .\default.ps1 -taskList Publish, Install

Get-Module psappinsights
Get-InstalledModule psappinsights -AllVersions

