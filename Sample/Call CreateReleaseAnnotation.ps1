
     $iKey = 'b437832d-a6b3-4bb4-b237-51308509747d' #AI PowerShell

     .\CreateReleaseAnnotation.ps1 `
      -applicationId "<applicationId>" `
      -apiKey $iKey `
      -releaseName "<myReleaseName>" `
      -releaseProperties @{
          "ReleaseDescription"="a description";
          "TriggerBy"="My Name" }


          