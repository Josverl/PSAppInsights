<#
 #  use Invoke-Psake to start the build
#>


Task default -Depends TestInstall

Properties {
    # The name of your module should match the basename of the PSD1 file.
    if ($PSScriptRoot ) { 
        $BasePath = $PSScriptRoot 
    } else {
        #Handle run in ISE 
        $BasePath = split-path -parent $psISE.CurrentFile.Fullpath
    }

    $ModuleName = (Get-Item $BasePath\*.psd1 | Foreach-Object {$null = Test-ModuleManifest -Path $_ -ErrorAction SilentlyContinue; if ($?) {$_}})[0].BaseName

    # The directory used to publish the module from.  If you are using Git, the
    # $PublishRootDir should be ignored if it is under the workspace directory.
    $PublishRootDir = "$BasePath\Release"
    $ReleaseDir     = "$PublishRootDir\$ModuleName"

    # The following items will not be copied to the $ReleaseDir.
    # Add items that should not be published with the module.
    $Exclude = @(
        'Release','Tests','.git*','.vscode','launch.json','*.tests.ps1',
        #donot copy nuget ballast
        'net40','tools','*.nupkg','Microsoft.ApplicationInsights.xml',
        #donot copy dev and build artefacts
        'scratch','build.ps1','default.ps1'
    )

    $TestRepository = "DevRepo" #$null
    # Name of the repository you wish to publish to. Default repo is the PSGallery.
    $PublishRepository = "PSGallery" #$null

    # Your NuGet API key for the PSGallery.  
    $NuGetApiKey = (Get-StoredCredential  -Target 'PSGallery:NuGetApiKey').GetNetworkCredential().Password
}
FormatTaskName "|>-------- {0} --------<|"

Task Test  {
    Import-Module Pester
    #$Results = Invoke-Pester -Script @( '.\connecto365.Tests.ps1','.\InstallModules.tests.ps1') -PassThru
    $Results = Invoke-Pester -PassThru

    if  ($Results.FailedCount -gt 0) {
        Throw "Testing Failed"
    }
}

Task Clean  -requiredVariables PublishRootDir `
            -description "Clean the Release Folder" `
            -Depends Test {
    # Sanity check the dir we are about to "clean".  If $PublishRootDir were to
    # inadvertently get set to $null, the Remove-Item commmand removes the
    # contents of \*.  
    Write-verbose "Clean : $PublishRootDir" -Verbose
    if ((Test-Path $PublishRootDir) -and $PublishRootDir.Contains($BasePath)) {
        Remove-Item $PublishRootDir\* -Recurse -Force
    }
}

Task Copy   -description "Copy items to the release folder" `
            -Depends Clean `
            -requiredVariables BasePath, ReleaseDir, Exclude, ModuleName {
    
    Write-verbose "Copy : $BasePath --> $ReleaseDir" -Verbose              
    MD $ReleaseDir -ErrorAction SilentlyContinue | Out-Null
    Copy-Item -Path $BasePath\*.* -Destination $ReleaseDir -Recurse -Exclude $Exclude 

}

Task Sign -Depends Copy {
   "Sign"
   #Must excluse the *.tests.ps1 files from the signing
}



Task TestPublish -Depends Copy {
    #remove the same version form the test repo, if it already exists
    $MFT = Test-ModuleManifest -Path (Join-Path $ReleaseDir -ChildPath "$moduleName.psd1") 
    Get-ChildItem -path ( (Get-PSRepository -Name "$TestRepository").SourceLocation) -Filter "$moduleName.$($MFT.Version.ToString()).nupkg" | remove-item

    $publishParams = @{} 
    $publishParams['Path']= $ReleaseDir

    if ($PublishRepository) {
        $publishParams['Repository'] = $TestRepository
    }

    # Consider not using -ReleaseNotes parameter when Update-ModuleManifest has been fixed.
    if ($ReleaseNotesPath) {
        $publishParams['ReleaseNotes'] = @(Get-Content $ReleaseNotesPath)
    }

    "Calling Publish-Module..."
    Publish-Module @publishParams 
}


Task TestInstall -Depends TestPublish{
   "Test Install"
   $MFT = Test-ModuleManifest -Path (Join-Path $ReleaseDir -ChildPath "$moduleName.psd1") 
   find-Module -Name $mft.Name -RequiredVersion $mft.version -Repository $TestRepository
   install-Module -Name $mft.Name -RequiredVersion $mft.version -Repository $TestRepository -Force 
   Get-InstalledModule -Name $mft.Name
}

Task Publish -Depends TestInstall {
    $publishParams = @{} 
    $publishParams['Path']= $ReleaseDir
    $publishParams['NuGetApiKey'] = $NuGetApiKey

    if ($PublishRepository) {
        $publishParams['Repository'] = $PublishRepository
    }

    # Consider not using -ReleaseNotes parameter when Update-ModuleManifest has been fixed.
    if ($ReleaseNotesPath) {
        $publishParams['ReleaseNotes'] = @(Get-Content $ReleaseNotesPath)
    }
    #Get the manifest
    $MFT = Test-ModuleManifest -Path (Join-Path $ReleaseDir -ChildPath "$moduleName.psd1") 
    #@Todo Check if Module Manifest version is newer than in PSGallery

    Publish-Module @publishParams
    install-Module -Name $mft.Name -RequiredVersion $mft.version -Repository $publishRepository -Force 

    Get-InstalledModule -Name $mft.Name

}
